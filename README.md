# UBPM

## Install

```bash
cmake -S . -B build
sudo cmake --install build
ubpm # Follow the instructions given by the script
```

## Usage

### Initializing a project

Run `ubpm init` and start editing `dependencies.cmake`.

### `ubpm_dependency()`

#### Common arguments

```cmake
ubpm_dependency(
    <NAME> # Required argument

    [BUILD_TYPE <build-type>]
    # If, for whatever reason, the dependency needs to be built with a specific
    # build type, then it can be defined here
    #
    # Default value is CMAKE_BUILD_TYPE

    [COMPONENTS <comp>...]
    # List of install component names to use when installing the dependency to
    # the prefix location
    #
    # For each <comp> the following command is run:
    # cmake --install <build-dir> --config <build-type> --component <comp>
    #
    # If omitted, then CMake will be run once without the component argument

    [SCRIPT_PATH <path>]
    # Path to a CMake script file that will be copied into the source directory
    # of the dependency
    #
    # This is useful if the dependency does not support clients using CMake or
    # the dependency does not have a well-behaved root list file, both of which
    # are - unfortunately - pretty common
    #
    # This can't be used with SOURCE_DIR type of dependencies
    #
    # Emits a warning the first time that the script file should be submitted
    # to the dependency as a patch, because there really shouldn't be a need to
    # do something like this

    ...
    # Source of dependencies, see below

    [OPTIONS]
    # Argument that marks the beginning of options to pass to the dependency
    #
    # This is a special boolean argument that marks the beginning of options.
    # It is necessary to do it this way, to correctly pass list arguments in
    # CMake

    [...]
    # List of arguments in the VARIABLE=VALUE format after OPTIONS
    #
    # These are passed on the command line as is
    #
    # Passing list arguments is supported, just make sure you pass them as
    # either bracket_argument or quoted_argument. See cmake-language(7)
)
```

#### From directory

```cmake
ubpm_dependency(
    <NAME> # Required argument

    SOURCE_DIR <dir>
    # Path to the dependency's source directory containing a CMakeLists.txt
)
```

#### From git

```cmake
ubpm_dependency(
    <NAME> # Required argument

    {GIT | GITHUB} <repository> <branch> [<commit>]
    # Location of the git repository, branch/tag and an optional commit hash
    #
    # The GITHUB argument will prefix the repository with https://github.com/
    # and continue processing in GIT mode
)
```

#### From archive

```cmake
ubpm_dependency(
    <NAME> # Required argument

    URL <url>
    # URL to a downloadable archive that contains the dependency's source code
    #
    # Only archives that can be unpacked by CMake are supported

    URL_HASH <hash>
    # Hash of the archive that's expected from the <url>
    #
    # Any hash supported by CMake can be used and the method will be inferred
    # from the length of the hash

    [PATH <path>]
    # Path to the source location in the archive
    #
    # If omitted, then UBPM will check for the usual GitHub style of archive,
    # where the source is a single directory deep
)
```

### GitHub Actions

```yml
    steps:
      - uses: actions/checkout@v1

      - uses: actions/cache@v2
        with:
          path: .ubpm
          key: ${{ hashFiles('dependencies.cmake') }}

      # This action sets the UBPM_MODULE_PATH env variable to the correct path
      - uses: friendlyanon/ubpm@pre-v3

      # No need to pass additional variables, UBPM just works
      - name: Configure
        run: cmake -S . -B build
```
