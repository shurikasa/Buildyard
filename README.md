# Buildyard

[Presentation.pdf](https://github.com/Eyescale/Buildyard/blob/master/doc/Presentation.pdf?raw=true)

## Quick Start

Buildyard facilitates the build and development of multiple, dependent
projects from installed packages, git or svn repositories. The following
projects are currently available, with optional projects drawn as
dotted bubbles, and optional dependencies linked using dotted arrows:

![Depency Graph](http://eyescale.github.com/images/all.png)

### Visual Studio

It is highly recommended to install a precompiled boost version using
the installers provided by BoostPro.

Use cmake to generate a Visual Studio Solution. Open this solution and
build it at least once to download and install all dependencies. See
'Targets' below for more details.

For development, open [build]/[Project]/[Project].sln and work there as
usual. This solution will build the (pre-configured) project without
considering any dependencies. Use the [build]/Buildyard.sln target to
build a project considering all dependencies.

### Others

On Ubuntu, use 'make apt-get' to install all known package
dependencies. On Mac OS X, use 'make port-get' to install all known
MacPorts dependencies.

Execute 'make build' or 'make [Project]' at least once, which downloads,
configures and builds debug versions of all or the specified project. See
'Targets' below for more details.

For development, cd into src/[Project] and work there as usual. The
default make target will build the (pre-configured) project without
considering any dependencies. 'make [Project]' will build the project
considering all dependencies.

Custom CMake binary directories are supported and can be used through
the top-level make using 'make BUILD=[directory]' or 'export
BUILD=[directory]; make'.

## Targets

### Generic Targets

The per-project targets below are also available as aggregate targets
for all projects, e.g., 'makes' builds all projects.

* apt-get: Install all packages using apt-get on Ubuntu.
* port-get: Install all MacPorts packages needed on Mac OS X.
* update: Update all Buildyard configurations when called from Buildyard
  source directory, and updates project when called from project source
  directory.
* info: Display the result of the last configuration run

### Per-Project Targets

* PROJECT: downloads, configures and build the project and all its
  dependencies. Typically only used in the beginning to bootstrap
* PROJECT-only: Build only the given project without considering
  dependencies, update and configure steps. This is the recommended way
  to rebuild a project in a bootstrapped Buildyard instance.
* PROJECT-make: Build the given project and all its dependencies without
  considering the update and configure steps. This is the recommended
  way to rebuild a project and all its dependencies in a bootstrapped
  Buildyard instance.
* PROJECT-projects: Build all non-optional dependees of the given project,
  useful for testing downstream projects after API changes.
* PROJECT-snapshot: Create one environment module including all
  dependencies (Release builds only)
* PROJECT-reset: Cleans all working changes in the project's source directory.
* PROJECT-stat: Run 'SCM status' on the project.

In addition, the targets created by ExternalProject.cmake (download,
update, configure, build and install) are also available, but are not
really useful in the context of Buildyard.

### In-source Targets

Buildyard will set up a Makefile in src/Project, if it is safe to do
so. This Makefile forwards to build/Project and allows to build all
targets defined by the project. It also provides the following,
additional targets:

* default: Build this project only, equivalent to PROJECT-only in the
  build directory
* all: Build this project and all dependencies, equivalent to
  PROJECT-make in the build directory
* configure: Reconfigure this project using cmake, equivalent to 'cmake
  Build/PROJECT'


## How does it work?

Buildyard uses simple configuration files grouped in per-organisation
config.[org] folders, for example
[config.eyescale](https://github.com/Eyescale/config). Simply clone the
desired config repositories into the Buildyard directory.

Each config folder may contain a depends.txt, which lists config folders
this config folder depends on. This allows extending the base
configuration with custom projects from other sources, e.g.,
https://github.com/Eyescale/config/blob/master/depends.txt

Each config folder contains project .cmake configuration files, for
example
[Equalizer.cmake](https://github.com/Eyescale/config/blob/master/Equalizer.cmake).
It contains the following variables:

* PROJECT\_VERSION: the required version of the project.
* PROJECT\_DEPENDS: list of dependencies, OPTIONAL and REQUIRED keywords
  are recognized. Projects with missing required dependencies will not
  be configured.
* PROJECT\_DEPENDEE\_COMPONENTS: list of COMPONENTS for find_package.
* PROJECT\_REPO\_TYPE: optional, git, git-svn or svn. Default is git.
* PROJECT\_REPO\_URL: git or svn repository URL.
* PROJECT\_REPO\_TAG: The svn revision or git tag to use to build the project.
* PROJECT\_ROOT\_VAR: optional CMake variable name for the project root,
  as required by the project find script. Default is PROJECT\_ROOT.
* PROJECT\_TAIL\_REVISION: The oldest revision a git-svn repository should
  be cloned with.
* PROJECT\_CMAKE\_ARGS: Additional CMake arguments for the configure
  step. The character '!' can be used to separate list items.
* PROJECT\_AUTOCONF: when set to true, the autoconf build system is used to
  build the project.
* PROJECT\_DEB\_DEPENDS: Debian package names of dependencies. Used for
  apt-get target and Travis CI configuration files.
* PROJECT\_PORT\_DEPENDS: MacPorts package names of dependencies. Used
  for port-get target.

The Buildyard CMakeLists pulls in all dependent config folders, reads
all .cmake files from the config* directories, and configures each
project using
[ExternalProject.cmake](http://www.kitware.com/media/html/BuildingExternalProjectsWithCMake2.8.html).

### Directory Layout

* config/ : The builtin configuration files
* config.[name] : a configuration module, e.g.,
  [config.eyescale](https://github.com/Eyescale/config)
* config.[name]/depends.txt : modules upon which the module
  depends, e.g.,
  [config.eyescale/depends.txt](https://github.com/Eyescale/config/blob/master/depends.txt).
  Dependencies will be cloned by Buildyard automatically.
* config.[name]/[Project].cmake : A project configuration file (see
  Configuration)
* Build/ : The build directory where all generated files end up.
* Build/[Project] : The per-project build directory, including binaries
* Release/... : Same as build, but for a 'make release' build
* src/ : The directories into which all project sources are cloned
* src/[Project] : The source directory for the project. You can work
  from here, since a Makefile is generated by Buildyard for you (see Using).

## Tips and Tricks
### Local overrides

For customizing the shipped configurations one can override and extend
those configurations with a config.local configuration folder, e.g.,
[eile's config.local](https://github.com/eile/config.local). Additional
options are available there to specify a user fork for instance. Note
that this options are only valid for git repositories:

* PROJECT\_USER\_URL: the URL of the new origin for the project
* PROJECT\_ORIGIN\_NAME: the new remote name of the original origin
  (optional, default 'root')

### Force build from source

Setting PROJECT\_FORCE\_BUILD to ON will disable finding installed versions
of the project, causing the project to be always build from source.

### Bootstrapping from project source

Buildyard does configure the project so it can self-bootstrap. This
requires the
[CMake subtree](https://github.com/Eyescale/CMake/blob/master/README.md)
in the project and the setup described in
[CMake/Buildyard.cmake](https://github.com/Eyescale/CMake/blob/master/README.md).

### Macports files

Buildyard automatically creates portfiles for MacPorts. Simply add
Buildyard/Build/install/ports to your sources:

```
sudo vi /opt/local/etc/macports/sources.conf
[...]
file:///Users/eilemann/Software/Buildyard/Build/install/ports/
[...]
sudo port install Equalizer +universal
```

## Known issues

* Boost build not automatically triggered on VS2010
([#17](https://github.com/Eyescale/Buildyard/issues/17))
