# Docker Alpine cfssl

For your [PKI] needs, this is another [Docker] image to ease [cfssl] usage.

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
cfssl gencert -initca ca-csr.json | cfssl json -bare ca
```

If you did not want to modify the default values, you could have simply issued:

```sh
cfssl print-defaults csr | cfssl gencert -initca - | cfssl json -bare ca
```

This will create three additional files:

- `ca.csr`: a [PEM formatted] file containing the [CSR] for your [CA];
- `ca-key.pem`: a [PEM formatted] file containing the private key of your [CA];
- `ca.pem`: a [PEM formatted] file containing the (self-)signed certificate of your [CA].

Then run the [cfssl] service which will answer your [API](https://github.com/cloudflare/cfssl/tree/master/doc/api) calls:

```sh
cfssl serve -ca-key=ca-key.pem -ca=ca.pem -address=0.0.0.0 -- -p 8888:8888
```

> In order to stop this instance, you will have to issue `docker stop <instance name>` (`<ctrl-c>` will not work).
> Use `docker ps` to find the name of the running instance.

You can test the service by asking for a new certificate and saving data to [PEM formatted] files:

```sh
curl -X POST -d '{"request":{"CN":"","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"","ST":"","L":"","O":""}]}}' http://localhost:8888/api/v1/cfssl/newcert | cfssl json server
```

You can then launch an [OpenSSL] server using this certificate:

```sh
openssl s_server -key server-key.pem -cert server.pem -accept 4433
```

And check that an [OpenSSL] client will connect to this server by trusting the [CA]:

```sh
openssl s_client -connect localhost:4433 -CAfile ca.pem
```

### Mutual authentication

The following uses the same [CA] for both client and server certificates but different [CA]s can be used.

Based on the previous section, you can also generate a client certificate:

```sh
curl -X POST -d '{"request":{"CN":"","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"","ST":"","L":"","O":""}]}}' http://localhost:8888/api/v1/cfssl/newcert | cfssl json client
```

You can then launch an [OpenSSL] server using this certificate and trusting client certificates emitted by the common [CA]:

```sh
openssl s_server -key server-key.pem -cert server.pem -accept 4433 -Verify 0 -CAfile ca.pem
```

Then check that an [OpenSSL] client will connect to this server by trusting the [CA] and using the previously created client certificate:

```sh
openssl s_client -connect localhost:4433 -CAfile ca.pem -key client-key.pem -cert client.pem
```

### Using signing profiles

Depending on what the certificate is intended for, different signing profiles might be used.

This can be detailed in the `cfssl serve` configuration file, a default configuration can easily be obtained:

```sh
cfssl print-defaults config > ca-config.json
```

Then you can start the API server by passing it this configuration file:

```sh
cfssl serve -config=ca-config.json -ca-key=ca-key.pem -ca=ca.pem -address=0.0.0.0 -- -p 8888:8888
```

Obtaining a new certificate now also means providing the signing profile to use in the request::

```sh
curl -X POST -d '{"request":{"CN":"","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"","ST":"","L":"","O":""}]},"profile":"client"}' http://localhost:8888/api/v1/cfssl/newcert
```

### Intermediate CA

The main goal of an intermediate [CA] is to avoid exposing the private key of your root [CA] on a "less trusted" site.
On this site, the intermediate [CA] will be used to deliver new certificates instead of using the root [CA].
Thus, the intermediate [CA] private key is used on this latter site and the intermediate [CA] can be revoked in case of a leakage.

The root [CA] keeps being the certificate that is trusted by clients, hence the use of certificate bundles when using a certificate delivered by the intermediate [CA].
This bundle contains both the newly delivered certificate and the intermediate [CA] certificate.
When receiving such a bundle the client can authenticate it by using the following chain of trust (`->` means "trusts" or "certifies"):

```
client -> root [CA] -> intermediate [CA] -> new certificate
```

For this to work, you first need to create an intermediate [CA] signed by the root [CA].

Again, you need a root [CA]:

```sh
cfssl print-defaults csr | cfssl gencert -initca - | cfssl json -bare ca
```

In order to create an intermediate [CA], you will need a [CSR]:

```sh
# this is a "it just works" CSR, do not use it for production purpose
echo '{"CN": "Intermediate CA"}' > ica-csr.json
```

You also need a specific signing profile to create intermediate [CA]s, save the following in `ica-config.json`:

```json
{
  "signing": {
    "profiles": {
      "intermediate": {
        "expiry": "8760h",
        "usages": ["signing", "key encipherment", "cert sign", "crl sign"],
	"ca_constraint": {"is_ca": true, "max_path_len":1}
      }
    }
  }
}
```

Create the intermediate [CA]:

```sh
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ica-config.json -profile=intermediate ica-csr.json | cfssl json -bare ica
```

> A warning will be emitted by `cfssl` due to the fact that the certificate of the intermediate [CA] lacks a `hosts` field.
> You can simply ignore this warning, this certificate will not in fact be used to authentify a website server.

You can now move the `ca-key.pem` file somewhere deep in a safe place secured by your own goblins and trolls.

Next step is to start a `cfssl` server instance using this intermediate [CA]:

```sh
cfssl serve -ca-key=ica-key.pem -ca=ica.pem -ca-bundle=ca.pem -int-bundle=ica.pem -address=0.0.0.0 -- -p 8888:8888
```

> Note that both options `-ca-bundle` and `-int-bundle` are used and that in this particular example:
>
> - only one root [CA] is known of and is part of the root [CA] bundle;
> - only one intermediate [CA] is known of and is part of the intermediate [CA] bundle.
>
> Thus `ca.pem` and `ica.pem` are directly used as certificate bundles both containing only one certificate.

This `cfssl` instance is able to:

- deliver new certificates based on the intermediate [CA] due to the use of `-ca-key` and `-ca` options;
- bundle certificates by knowing all root and intermediate certificates available (through bundle options).

> Root certificates will not be included in the bundles produced by `cfssl` as they are supposed to be trusted by the other party during the TLS handshake.
> Intermediate certificates will be added to the produced bundles in order to complete the certificate chain up to an intermediate certificate that is signed by a root certificate.

You can then generate a server certificate and its bundle with the following command:

```sh
curl -X POST -d "$(curl -X POST -d '{"request":{"CN":"localhost","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"","ST":"","L":"","O":""}]}}' http://localhost:8888/api/v1/cfssl/newcert | tee >(cfssl json server) | jq -M '.result.certificate | {certificate: .}')" http://localhost:8888/api/v1/cfssl/bundle | jq -M '.result.bundle | {certificate: .}' | cfssl json -bare server-bundle
```

> This command is a bit intricate, let's break it down:
>
> - the `newcert` API is used to generate a new certificate;
> - the output is forked with `tee` and passed to `cfssl json` to write the certificate and its key respectively to `server.pem` and `server-key.pem`
> - the same output is passed to the [jq] command to generate a `bundle` API request (`{certificate: <new certificate>}`);
> - the `bundle` API ingests this request and its [JSON] result is again processed by [jq] and written in the file `server-bundle.pem`.

Four files result from this command:

- `server.pem`: the new certificate;
- `server-key.pem`: the private key associated with this new certificate;
- `server.csr`: the [CSR] used to generate the new certificate;
- `server-bundle.pem`: the new certificate bundle.

The `server-bundle.pem` contains in fact two certificates:

- first the newly created certificate which is signed by the intermediate certificate;
- then the intermediate certificate which is signed by the root certificate.

The [OpenSSL] `s_server` command seems unable to use a certificate bundle (or at least I did not find a way to do so).
Instead you can use this simple [Python] script (save it in `https.py`):

```python
import BaseHTTPServer, SimpleHTTPServer
import ssl

httpd = BaseHTTPServer.HTTPServer(('localhost', 4433), SimpleHTTPServer.SimpleHTTPRequestHandler)
httpd.socket = ssl.wrap_socket (httpd.socket, certfile='./server-bundle.pem', keyfile='./server-key.pem', server_side=True)
httpd.serve_forever()
```

You can then launch the [Python] HTTPS server using the certificate bundle:

```sh
python https.py
```

And check that an [OpenSSL] client will connect successfully to this server by trusting the [CA]:

```sh
openssl s_client -connect localhost:4433 -CAfile ca.pem
```


[bash]: https://www.docker.com/
[CA]: https://en.wikipedia.org/wiki/Certificate_authority
[cfssl]: https://cfssl.org/
[CSR]: https://en.wikipedia.org/wiki/Certificate_signing_request
[Docker]: https://www.docker.com/
[Docker Compose]: https://docs.docker.com/compose/
[jq]: https://stedolan.github.io/jq/
[JSON]: http://json.org/
[OpenSSL]: https://www.openssl.org/
[Python]: https://www.python.org/
[PEM formatted]: https://en.wikipedia.org/wiki/X.509#Certificate_filename_extensions
[PKI]: https://en.wikipedia.org/wiki/Public_key_infrastructure
