{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [
    (python3.withPackages (ps: with ps; [
      pandas
      python-dotenv
      pip
    ]))
  ];

  shellHook = ''
    if [ ! -d .venv ]; then
      python3 -m venv .venv --system-site-packages
      .venv/bin/pip install oracledb --quiet
    fi
    source .venv/bin/activate
    echo "Oracle RAC shell — oracledb $(python3 -c 'import oracledb; print(oracledb.__version__)')"
  '';
}
