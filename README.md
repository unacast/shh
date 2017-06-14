# shh

There are two main objectives with `shh`:

* Make it a little bit easier to work with [git secret](http://git-secret.io/)
* Connect `git secret` with kubernetes on google cloud


shh is a set of scripts that helps you to work with git secrets in combination with kubernetes on google cloud.

## Prerequisites

To use the helper scripts on top of `git secret` you need to have the following installed:

* GPG Tools: [https://gpgtools.org/](https://gpgtools.org/)
* Git secret: [http://git-secret.io/](http://git-secret.io/) (OSX: `brew install git-secret)

If you also intend to use the helpers for kubernetes on google cloud you need to have the following installed

* gcloud: [https://cloud.google.com/sdk/downloads](https://cloud.google.com/sdk/downloads)
* kubectl: [https://cloud.google.com/container-engine/docs/quickstart#install_the_gcloud_command-line_tool](https://cloud.google.com/container-engine/docs/quickstart#install_the_gcloud_command-line_tool)

## Usage

### Initialization

To initialize the repo you need to add a user to your `GPG Keychain`, and to do do that you install the `gpgtools` and then starts `GPG keychain`. The email you use for this user is what you will use when you initialize the repo.

Before you can start adding secrets you need to initialize the repoistory. Start by forking this repo and then run

    scripts/init.sh

The script will ask you for the email of the first user to use when encrypting secrets.

### Adding a user

Whenever you want to add a user you need that users public gpg key. So the user must also install `gpgtools` and create a key pair and share the public key with someone who is already added to the repo. The public key is share by exporting the key from `GPG keychain`. When you have the public key file you run

    scripts/add-user.sh <path to public key> <email associated with that public key>

### Adding a secret

All the secrets you add must be put in one file per secret. Note that if you have a new line in your file that will be interpreted as part of the secret. When you have a secret file you just run

    scripts/add-secret.sh <secret file>

When you run that command an encrypted version will be generated which is added to git, and at the same time the actual file will be added to `.gitignore` so we don't check in the actual secret.

### Removing a secret

Works almost the same as adding, but instead you run

    scripts/remove-secret.sh <secret file>

### Secrets and kubernetes

To deal with kubernetes secrets a convention is enforced in `shh`. All the secrets that you want to use in combination with kubernetes must be stored in the form: `secrets/<category>/<sub category>/<secret file>`.

#### Creating kubernetes secret

First add a secret following the convention mentioned above, `secrets/<category>/<sub category>/<secret file>`, by using the `add-secret.sh` script. When you have prepared one or more secrets you can add them to a kubernetes secret by running:

    scripts/shh.sh -n <secret name> [<category>/<sub category>]

Concrete example:

    scripts/shh.sh -n my_app_secrets partnerX/s3 partnerY/gcp

That will take all the secrets in folders `secrets/partnerX/s3` and `secrets/partnerY/gcp` and generate a kubernetes secret named `my_app_secrets` which you can use in your kubernetes cluster.

#### Adding a git secret to a kubernetes secret

To add a new git secret a kubernetes secret you run the following

    scripts/shh.sh -n <secret name> -a <category>/<sub category>

Concrete example:

    scripts/shh.sh -n my_app_secrets -a partnerZ/s3

That will read the `my_app_secrets` secret from kubernetes and add the secrets for `partnerZ/s3` and update it in kubernetes.

#### Updating all the kubernetes secrets that are using a git secret

If you want to update an existing secret it might be important that it gets updated in all the kubernetes secrets it is used. And to do so you run

    scripts/shh.sh -r <category>/<sub category>

Concrete example:

    scripts/shh.sh -r partnerY/gcp

If you haven't noticed before, every time you add a secret we create a file in the repo to indicate where it has been added. You can see that as a file based database. Whey you run `shh.sh` with `-r` it will check all the apps (or kubernetes secrets), in the current environment, and update those. If you have secrets that are used in multiple environments you need to run it multiple times.
