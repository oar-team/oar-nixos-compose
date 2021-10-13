{ nixpkgs, system, compositions, flavour, extraConfigurations }:
let
  pkgs = (import nixpkgs) { inherit system; };
  lib = pkgs.lib;
  modulesPath = "${toString nixpkgs}/nixos";
  flavours = import ./flavours.nix;
  generate = import ./generate_one_composition_info.nix;

  allCompositionsInfo = lib.mapAttrs (compositionName: composition:
    generate { inherit pkgs modulesPath system extraConfigurations flavour; } {
      inherit compositionName composition;
    }) compositions;

  allCompositionsInfoFile = pkgs.writeText "compositions-info.json"
    (builtins.toJSON allCompositionsInfo);

  allMergedStorePaths =
    lib.mapAttrsToList (n: m: "${m.all_store_info}/merged-store-paths")
    allCompositionsInfo;
  allCompositionsInfoPaths =
    lib.mapAttrsToList (n: m: "${m.all_store_info}") allCompositionsInfo;

  allCompositionsImage = import ./make-system-tarball.nix {
    fileName = "all-compositions";
    stdenv = pkgs.stdenv;
    closureInfo = pkgs.closureInfo;
    pixz = pkgs.pixz;
    registrationStorePath = "${allCompositionsRegistrationStorePath}";
    storeContents = [{
      object = baseConfig.system.build.toplevel;
      symlink = "/run/current-system";
    }];

    contents = [
      {
        source = baseConfig.system.build.initialRamdisk + "/"
          + baseConfig.system.boot.loader.initrdFile;
        target = "/boot/" + baseConfig.system.boot.loader.initrdFile;
      }
      {
        source = baseConfig.boot.kernelPackages.kernel + "/"
          + baseConfig.system.boot.loader.kernelFile;
        target = "/boot/" + baseConfig.system.boot.loader.kernelFile;
      }
      {
        source = "${
            builtins.unsafeDiscardStringContext baseConfig.system.build.toplevel
          }/init";
        target = "/boot/init";
      }
      {
        source = "${allCompositionsInfoFile}";
        target = "/nix/store/compositions-info.json";
      }
    ];
  };

  allCompositionsRegistrationStorePath = pkgs.stdenv.mkDerivation {
    name = "all-compositions-registration-store-paths";

    buildCommand = ''
      mkdir $out
      sort ${
        builtins.concatStringsSep " " allMergedStorePaths
      } | uniq > $out/all-store-paths

      IFS=' ' read -r -a allCompositionsInfoPaths <<< "${
        builtins.concatStringsSep " " allCompositionsInfoPaths
      }"

      for compositionsInfoPath in "''${allCompositionsInfoPaths[@]}"
      do
        for registrationFile in "$compositionsInfoPath"/nix-path-registration*
        do
          cp $registrationFile $out
          echo "copy $registrationFile"
          allRegistrations="$allRegistrations $registrationFile"
        done
      done
    '';
  };

  allCompositionsSquashfsStore = pkgs.stdenv.mkDerivation {
    name = "all-compositions-squashfs.img";

    nativeBuildInputs = [ pkgs.squashfsTools ];

    buildCommand = ''
      allMergedStorePaths=$(sort ${
        builtins.concatStringsSep " " allMergedStorePaths
      } | uniq)

      IFS=' ' read -r -a allCompositionsInfoPaths <<< "${
        builtins.concatStringsSep " " allCompositionsInfoPaths
      }"

      allRegistrations=""
      for compositionsInfoPath in "''${allCompositionsInfoPaths[@]}"
      do
        for registrationFile in "$compositionsInfoPath"/nix-path-registration*
        do
          cp $registrationFile .
          echo "copy $registrationFile"
          allRegistrations="$allRegistrations $registrationFile"
        done
      done

      # copy allCompositionsInfoFile
      echo "allCompositionsInfoFile"
      cp ${allCompositionsInfoFile} compositions-info.json

      # Generate the squashfs image.
      mksquashfs  $allRegistrations $allMergedStorePaths compositions-info.json $out \
        -keep-as-directory -all-root -b 1048576 -comp gzip -Xcompression-level 1;
    '';
  };

  baseConfig = (generate {
    inherit pkgs modulesPath system extraConfigurations flavour;
    baseConfig = true;
  } { }).config;

  baseImage =
    pkgs.runCommand "image" { buildInputs = [ pkgs.nukeReferences ]; } ''
      mkdir $out
      cp ${baseConfig.system.build.kernel}/bzImage $out/kernel
      echo "init=${
        builtins.unsafeDiscardStringContext baseConfig.system.build.toplevel
      }/init ${toString baseConfig.boot.kernelParams}" > $out/cmdline
      nuke-refs $out/kernel
    '';

  allRamdisk = pkgs.makeInitrd {
    inherit (baseConfig.boot.initrd) compressor;
    prepend = [ "${baseConfig.system.build.initialRamdisk}/initrd" ];

    contents = [{
      object = allCompositionsSquashfsStore;
      symlink = "/nix-store.squashfs";
    }];
  };

in let
  flavoured_all = if flavour ? image && flavour.image ? type
  && flavour.image.type == "ramdisk" then {
    compositions_squashfs_store = allCompositionsSquashfsStore;
    all = {
      qemu_script = "${baseConfig.system.build.qemu_script}";
      initrd = "${allRamdisk}/initrd";
    };

  } else {
    all = {
      image = "${allCompositionsImage}/tarball/all-compositions.tar.xz";
      initrd = "${baseConfig.system.build.initialRamdisk}/initrd";
      all_compositions_registration_store_path =
        "${allCompositionsRegistrationStorePath}";
      init = "${
          builtins.unsafeDiscardStringContext baseConfig.system.build.toplevel
        }/init";
    };
  };

in pkgs.writeText "compose-info.json" (builtins.toJSON (lib.recursiveUpdate {
  flavour =
    lib.filterAttrs (n: v: n == "name" || n == "description" || n == "image")
    flavour;
  compositions_info = allCompositionsInfo;
  all = {
    kernel = "${baseImage}/kernel";
    stage1 = "${baseConfig.system.build.bootStage1}";
  };
} flavoured_all))
