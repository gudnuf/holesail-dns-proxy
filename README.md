Still a work in progress.

## Goal

Holesail allows you to connect two machines without any firewall configuration or headaches... it just works.

I want to use holesail to self-host software that I can expose to the public internet (ie. a blog).

I describe in [this gist](https://gist.github.com/gudnuf/d3f797a7f69a819c12ae7765e288cf8b) how a cashu mint running at your house can be connected to any other machine using holesail.

I successfully set up a proxy running on aws that takes incoming requests made to a domain and forwards them to the port that holesail is using. That was using the [setup_nginx.sh](./setup_nginx.sh) which works, but I want it to work with nix.

I also want this to be much more dynamic. You should be able to forward traffic from any domain to any port.

## Use

If you already have holesail installed on a cloud server and your self-hosted machine, then all you need to do is:

1. use holesail to connect to you home server
```bash
holesail <connection_string> --port 3338
```
2. Modify the `proxy_pass` in  `setup_nginx` script to match the port that holesail is making live
3. run nginx
```bash
./setup_nginx.sh
```
You will need a domain to use, when prompted enter that. This script will then generate ssl certs for you.

That should be it!
