# Archimate container image for CI

[Archi][Archi repository] container image for use in continuous integration
pipelines. With this container, you can implement automatic report generation
and model export in your pipeline.

The [Archi][] modelling toolkit is targeted toward all levels of Enterprise
Architects and Modellers.

For collaboration with models in the git repository, the [coArchi][] plugin
is installed in the container.

<p align="center" width="100%">
  <img src="https://raw.githubusercontent.com/WoozyMasta/archimate-ci-image/master/scheme.png" />
</p>

For ease of use, the docker-entrypoint.sh script is run in the container,
which processes the environment variables, and the native git client is used
for cloning.

## Run Container

Example with cloning a remote repository:

```bash
mkdir -p ./archi

docker run --rm \
  -v $(pwd)/archi:/archi \
  -e GIT_REPOSITORY=git@github.com:archimatetool/example.git
  woozymasta/archimate-ci:4.8.1
```

An example with handling a local repository:

```bash
mkdir -p ./report

docker run --rm \
  -v /path/to/model:/archi/project \
  -v $(pwd)/report:/archi/report \
  woozymasta/archimate-ci:4.8.1
```

Working with the CLI directly:

```bash
docker run --rm -ti \
  -v $(pwd)/archi:/archi \
  woozymasta/archimate-ci:4.8.1 --help
```

## Configuration

Configuration for connecting to the git repository:

* **`GIT_REPOSITORY`** - Git repository address;
* **`GIT_TOKEN`** - Token for accessing the git repository. Preferred
  for private repositories, or use a key mounted in an ssh container;
* **`GIT_USERNAME`** - Username (_it is better to use token or ssh key_);
* **`GIT_PASSWORD`** - Password (_it is better to use token or ssh key_).

Options for managing model export:

* **`MODEL_PATH`**=`/archi/project` - The path where the git repository with
  the architectural model will be cloned or connected;
* **`REPORT_PATH`**=`/archi/report` - Path where reports will be saved;
* **`HTML_REPORT_ENABLED`**=`true` - Generate HTML report;
* **`JASPER_REPORT_ENABLED`**=`true` - Generate Jasper reports;
* **`JASPER_REPORT_FORMATS`**=`PDF,DOCX` - Formats for Jasper reports should be
  separated by commas. Valid values: `PDF`, `HTML`, `RTF`, `PPT`, `ODT`, `DOCX`;
* **`JASPER_REPORT_TITLE`** - The title for the Jasper report, the default is
  the project name;
* **`CSV_REPORT_ENABLED`**=`true` - Generate CSV report;
* **`EXPORT_MODEL_ENABLED`**=`true` - Export model in `*.archimate` format.

## Build Container

```bash
docker build \
  --tag archimate-ci:4.8.1 \
  --build-arg="ARCHI_VERSION=4.8.1" \
  --build-arg="COARCHI_VERSION=0.7.1.202102021056" \
  ./
```

## Solving Potential Problems

If you are using a private git repository hosted behind a VPN, the tunnel
interface or name resolution might not be available in the container, use the
host network in the container and force the DNS record forward.

```bash
docker run --rm \
  -v $(pwd)/archi:/archi \
  -e GIT_REPOSITORY=git@github.com:archimatetool/example.git
  --network=host
  --add-host="$(getent hosts gitlab.internal.tld | awk '{print $2 ":" $1}')"
  woozymasta/archimate-ci:4.8.1
```

<!-- links -->

[Archi]: https://www.archimatetool.com "The Open Source modelling toolkit for creating ArchiMate models and sketches."
[Archi repository]: https://github.com/archimatetool/archi "Archi: ArchiMate Modelling Tool "
[coArchi]: https://github.com/archimatetool/archi-modelrepository-plugin "coArchi – Model Collaboration for Archi"
