# Docker Alpine cfssl

For your [PKI] needs, this is another [Docker] container to ease [cfssl] usage.

The image is [Alpine](https://alpinelinux.org/) based in order to reduce its footprint.


## Basic usage

First thing to do is to get the [cfssl executable](https://github.com/gautaz/docker-alpine-cfssl/blob/master/bin/cfssl):

```sh
curl -LO https://github.com/gautaz/docker-alpine-cfssl/raw/master/bin/cfssl
chmod u+x cfssl
```

Then add the `cfssl` [bash] script location to your `PATH`.

You may use the [Docker] image directly if [bash] is not available on your platform by issuing:

```sh
docker run --rm -i -v "${PWD}:/home/cfssl" "${dockerargs[@]}" gautaz/alpine-cfssl "${cfsslargs[@]}"
```

Where `dockerargs` and `cfsslargs` are additional arguments to pass to [Docker run](https://docs.docker.com/engine/reference/run/) and the instance entry point.
But operating this way can be rather daunting.

### Getting help

Simply issue `cfssl` on the command line to get the general help page.
Basically `cfssl` will give you access to a set of commands provided by [cfssl].
The general syntax is `cfssl <command> [option...]`.

In order to get help for a particular command simply issue `cfssl <command> -h` where `<command>` is the command you want help for.

### Shell script goal

The `cfssl` script is designed to enable piping which is necessary to operate part of the flow needed to operate a [PKI] with [cfssl].
In particular some [cfssl] commands may output [JSON] content that is to be used by other commands.

However this script will not behave well when the goal is to operate a daemon.
Once all of your [PKI] environment has been built up, you might want to use the image directly with [Docker Compose] without using the `cfssl` shell script.


## Operating a [PKI]

 A few steps are generally needed in order to obtain a fully working [PKI] with [cfssl]:

- creating a root certificate authority ([CA]);
- optionally creating an intermediate [CA];
- starting [cfssl] as a service;
- querying the [cfssl] API to manage certificates.

### Most basic flow

Having `cfssl` available, operate the following commands in a test folder.

Create a certificate signing request ([CSR]) [JSON] configuration file:

```sh
cfssl print-defaults csr > ca-csr.json
```

This will create a default [CSR] configuration that you might want to modify in order to fit your needs.
Once you have edited the file, you can generate everything needed to operate your own [CA]:

```sh
cfssl gencert -initca ca-csr.json | cfssl json -bare ca -
```

If you did not want to modify the default values, you could have simply issued:

```sh
cfssl print-defaults csr | cfssl gencert -initca - | cfssl json -bare ca -
```

This will create three additional files:

- `ca.csr`: a [PEM formatted] file containing the [CSR] for your [CA];
- `ca-key.pem`: a [PEM formatted] file containing the private key of your [CA];
- `ca.pem`: a [PEM formatted] file containing the (self-)signed certificate of your [CA].

Then run the [cfssl] service which will answer your [API](https://github.com/cloudflare/cfssl/tree/master/doc/api) calls:

```sh
cfssl serve -ca-key ca-key.pem -ca ca.pem -address=0.0.0.0 -- -p 8888:8888
```

You can test by asking for a new certificate:

```sh
curl -X POST -d '{"request":{"CN":"","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"","ST":"","L":"","O":""}]}}' http://localhost:8888/api/v1/cfssl/newcert
```

In order to stop this container, you will have to issue `docker stop <container name>` (`<ctrl-c>` will not work).
Use `docker ps` to find the name of the running container.


[bash]: https://www.docker.com/
[CA]: https://en.wikipedia.org/wiki/Certificate_authority
[cfssl]: https://cfssl.org/
[CSR]: https://en.wikipedia.org/wiki/Certificate_signing_request
[Docker]: https://www.docker.com/
[Docker Compose]: https://docs.docker.com/compose/
[JSON]: http://json.org/
[PEM formatted]: https://en.wikipedia.org/wiki/X.509#Certificate_filename_extensions
[PKI]: https://en.wikipedia.org/wiki/Public_key_infrastructure
