Needed to install [node2nix](https://github.com/svanderburg/node2nix):

With flakes:

```
nix profile install nixpkgs#node2nix
```

## Generating a nix expression for holesail

Install holesail:

```
npm init -y
npm install --save holesail
```

Delete `package-lock.json` and `node_modules` directory.

Generate a nix expression for holesail:

```
node2nix
```

This generates a `node-packages.nix`, `default.nix`, `node-env.nix` file in the current directory.

## Goal

Trying to replicate what I have in setup_nginx.sh and install_holesail.sh:
