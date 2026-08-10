# CII Best Practices CircleCI Dockerfiles

This directory contains directories and Dockerfiles for the custom
images used in the app's CI pipeline on CircleCI.  When upgrading ruby,
it is best to copy the folder and name it according to the CircleCI base
image you are using.

To upgrade the docker image you must have an account on DockerHub and docker
installed on your computer (Install instructions are
[here](https://docs.docker.com/install/).

See [how-to-create-image.md](how-to-create-image.md) for detailed
instructions. Here are the highlights:

1. Create a new directory and copy an existing Dockerfile into the new
   directory as described above.
2. "cd" into that directory and modify the Dockerfile
   to point to the correct base image.
3. Log in to DockerHub

    ~~~~sh
    docker login -u <username>
    ~~~~

4. Build the docker image (replace `<tag>` below with for example
   `2.5.1-stretch`.

    ~~~~sh
    docker build -t <username>/cii-bestpractices:<tag> .
    ~~~~

5. Push your image.

    ~~~~sh
    docker push <username>/cii-bestpractices:<tag>
    ~~~~

Once completed you must then update `.circleci/config.yml` to use the new image.
You should also add your new/updated Dockerfile to version control.

Note that, as required by OpenSSF Scorecard, you should pin the dependencies
to specific hash values instead of versions, so that changes (which might
be malicious) won't be silently accepted. See the existing
Dockerfile(s) and CircleCI configuration file for how to do that.
