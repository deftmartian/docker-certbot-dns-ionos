# docker-certbot-dns-ionos

![Contributors](https://img.shields.io/github/contributors/gianmarco-mameli/docker-certbot-dns-ionos?style=plastic) ![Forks](https://img.shields.io/github/forks/gianmarco-mameli/docker-certbot-dns-ionos?style=plastic) ![Stargazers](https://img.shields.io/github/stars/gianmarco-mameli/docker-certbot-dns-ionos?style=plastic) ![Issues](https://img.shields.io/github/issues/gianmarco-mameli/docker-certbot-dns-ionos?style=plastic) ![License](https://img.shields.io/github/license/gianmarco-mameli/docker-certbot-dns-ionos?style=plastic)

I created a Docker image for certbot-dns-ionos plugin from <https://github.com/helgeerbe/certbot-dns-ionos> project

The image is based on certbot original image with the addition of the plugin and include some variations to run all the scripts as non root user, set some permissions and schedule the certificate update with 'supercronic'.
The only script that run with highest privileges is for settings some folder permission and it's limited by "doas" command.

You need mapping of the following internal folders, that certbot uses as base dirs.

```ini
- /certbot # base folder
- /certbot/etc/letsencrypt/live # generated certificates folder
- /certbot/etc/letsencrypt/.secrets # path containing Ionos credential file
```

Create the file containing the credentials for the ionos api login, you can specify the path via env variable (change the volume accordingly).
Make sure you created the API key on [Ionos control panel](https://developer.hosting.ionos.it/keys)

This is the template to use (also available in the repository ionos.ini.tmpl or in the original [project repo](https://github.com/helgeerbe/certbot-dns-ionos#credentials))

```ini
# Instructions: <https://github.com/helgeerbe/certbot-dns-ionos>
# Replace with your values
dns_ionos_prefix = # ionos api prefix
dns_ionos_secret = # ionos api secret
dns_ionos_endpoint = # ionos api endpoint, ex. <https://api.hosting.ionos.com>
```

Finally need the following environment variables to make it work

```ini
IONOS_CREDENTIALS=/certbot/etc/letsencrypt/.secrets/ionos.ini # the path of the credential file ionos.ini
IONOS_CRONTAB=0 13 * * * # the supercronic schedule, in crontab format
IONOS_DOMAINS=test.ionos.io,test2.ionos.io # the domains to use on certificate renew, multiple entry comma separated
IONOS_PROPAGATION=300 # the seconds to wait for ionos dns propagation
IONOS_EMAIL=test@test.com # your ionos account email
```

## Usage

The image is available on Dockerhub <https://hub.docker.com/r/gmmserv/docker-certbot-dns-ionos>

For a fast run from command line with the following example make sure:

- you created all dirs to mount as volume
- you created the 'ionos.ini' file with correct credentials under ~/certbot/etc/letsencrypt/.secrets
- create a .env file, for simplicity, with all the envs needed

```shell
docker run -v ~/certbot:/certbot
           -v ~/certbot/etc/letsencrypt/live:/certbot/etc/letsencrypt/live
           -v ~/certbot/etc/letsencrypt/.secrets:/certbot/etc/letsencrypt/.secrets
           --env-file .env
           gmmserv/docker-certbot-dns-ionos:2024.1.8
```

The repo contains also a docker-compose file for example service

## Build

If you want to build the image with your mods or customization you can find on the repo the Dockerfile used and a docker-bake.hcl file for multi architectures with buildx. Also there's a Gitlab pipeline that I use to build the images pushed to Dockerhub and a personal Harbor Registry

Make sure to pass the following args

```ini
VERSION = # version of the image (I'm using the version of the Ionos certbot plugin)
CERTBOT_VERSION = # version of the certbot image used as base
```

Also possible to pass UID and GID to set cert default owner

```ini
USER_UID=1883 
USER_GID=1883 
```

Example of a simple build with "docker build"

```shell
docker build
     --build-arg VERSION=2024.11.09 
     --build-arg CERTBOT_VERSION=v4.1.1
     -t docker-certbot-dns-ionos:2024.11.09  .
```

Example of a multi architecture build with "docker buildx", you need to first create a builder using the binfmt image. Have a look at the docker-bake.hcl file for other parameters
My file iso configured to build 4 platforms, 'linux/amd64','linux/arm64','linux/arm/v7','linux/arm/v6'

```shell
export IMAGE_NAME=docker-certbot-dns-ionos
export VERSION=2024.11.09 
export CERTBOT_VERSION=v4.1.1
export REGISTRY_IMAGE="${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}"
export REGISTRY_IMAGE_PUBLIC="${DOCKERHUB_USER}/${IMAGE_NAME}"
export BUILDER_IMAGE="${IMAGE_NAME}-builder"
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create --use --bootstrap --name ${BUILDER_IMAGE} --config=buildkitd.toml
docker buildx bake --push --file docker-bake.hcl --progress plain
```

If you want to build with Gitlab, like me, have a look at the .gitlab-ci.yml, and set variables needed by the runner to execute. Pay particular attention to the 'buildkitd.toml.tmpl' file, you need to configure and rename to toml, for using custom signed CA Certificates for private registries. You can omit that file for pushing to dockerhub, also make sure to comment the "buildkit_toml" job on the pipeline.

## Customization

This project is written keeping in mind my necessities so I reccomend you to check all the sources before use it or launch it

## Issues, bugs, requests, collaboration

Feel free to open issues or pull requests if you find bugs or feature lack

## Next steps

- enable/disable supercronic if needed, for use with external scheduler
- better separation of Harbor and DockerHUB publish
- add other parameters to certbot

Any idea is welcome :)

### Credits, Tools and links

- [certbot](https://github.com/certbot/certbot)
- [certbot-dns-ionos](https://github.com/helgeerbe/certbot-dns-ionos)
- [supercronic](https://github.com/aptible/supercronic)
- [doas](https://github.com/Duncaen/OpenDoas)
- [pushrm](https://github.com/christian-korneck/docker-pushrm)

### Support

<a href="https://www.buymeacoffee.com/app/gianmarcomameli"> <img src="https://cdn.simpleicons.org/buymeacoffee" alt="buymeacoffe" height="32" /></a>
<a href="https://ko-fi.com/gianmarcomameli"> <img src="https://cdn.simpleicons.org/kofi" alt="kofi" height="32"/></a>
