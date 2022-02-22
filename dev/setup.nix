{nur ? null, file ? ./setup.toml } :
let
  # mapListToAttrs (o: {${o}=1;}) [ "a" "b"]  
  # { a = 1; b = 1; }
  
  setup = builtins.fromTOML (builtins.readFile file);
  
 # mapListToAttrs (o: {${o}=o+"-2";}) [ "a" "b"] 
 # { a = "a-2"; b = "b-2"; }
  mapListToAttrs = op: list:
    let
      len = builtins.length list;
      g = n: s:
        if n == len 
        then s
        else g (n+1) (s // (op (builtins.elemAt list n)));
    in
      g 0 {};
  
  # mapAttrNamesToAttrs (o: {${o}=o+"-2";}) { a = 1; b = 2; }
  # { a = "a-2"; b = "b-2"; }
  mapAttrNamesToAttrs = op: attrs: mapListToAttrs op (builtins.attrNames attrs);
  
  # mapAttrsToAttrs (n: v: {${n+"2"}=1+v;}) { a = 1; b = 2; }
  # { a2 = 2; b2 = 3; }
  mapAttrsToAttrs = op: attrs:
    let
      list = builtins.attrNames attrs;
      len = builtins.length list;
      g = n: s:
        if n == len 
        then s
        else
          let
            attrName = builtins.elemAt list n;
            value = attrs.${attrName};
          in
          g (n+1) (s // (op attrName value));
    in
      g 0 {};

  #conf_repos = { kapack = { oar = { src= (/. + "/home/auguste/dev/oar3");}; }; };
  #conf_repos = { kapack = { oar = { src= /home/auguste/dev/oar3;}; }; };

  adaptAttr = attrName: value:
    {
      ${attrName} = (if (attrName == "src") && (builtins.isString value) then
       /. + value
    else
      value) ;
    };

in {
  overrides = if builtins.hasAttr "overrides" setup then
    if (builtins.hasAttr "nur" setup.overrides) && (nur != null) then
      [
        (self: super: 
          let
            overrides = repo: builtins.mapAttrs (name: value: super.nur.repos.${repo}.${name}.overrideAttrs (old: mapAttrsToAttrs adaptAttr value)) setup.overrides.nur.${repo}; 
          in
            mapAttrNamesToAttrs (repo: {nur.repos.${repo} = super.nur.repos.${repo} // (overrides repo);}) setup.overrides.nur
        )
      ]
    else []
              else
                [];
}
