{
  description = "cl-cc-php: PHP frontend (lexer, parser, grammar, runtime builtins) for the cl-cc Common Lisp compiler";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Compiler systems are pinned to their child-main snapshots from the
    # umbrella pinset so this flake consumes only the packages it needs.
    cl-cc-bootstrap = {
      url = "github:nerima-lisp/cl-cc-bootstrap/027f6c9826010c15789454e69abd2930738b50af";
      flake = false;
    };
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/a45c5acecfccb91a43f6a04251e8a5d6ec3d3213";
      flake = false;
    };
    cl-cc-parse = {
      url = "github:nerima-lisp/cl-cc-parse/75d8699835731ec6ca44e15c82ef02601f5100fe";
      flake = false;
    };
    cl-cc-runtime = {
      url = "github:nerima-lisp/cl-cc-runtime/d23ea44512b162def39ec981426c4c8e1af4df84";
      flake = false;
    };
    cl-cc-vm = {
      url = "github:nerima-lisp/cl-cc-vm/462213fcf5e0e6cecc09992e8cb0b7ed48dbce2f";
      flake = false;
    };

    # Plain source inputs are resolved by the ASDF source registry in the
    # test and coverage scripts.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      flake = false;
    };
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit/v1.1.1";
      flake = false;
    };
    cl-regex-kit = {
      url = "github:nerima-lisp/cl-regex-kit/v2.2.0";
      flake = false;
    };
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.6.1";
      flake = false;
    };
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v2.2.0";
      flake = false;
    };
    cl-process-kit = {
      url = "github:nerima-lisp/cl-process-kit/v3.4.0";
      flake = false;
    };
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.6.0";
      flake = false;
    };
    cl-concurrent-kit = {
      url = "github:nerima-lisp/cl-concurrent-kit/v0.6.1";
      flake = false;
    };
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.3.0";
      flake = false;
    };
    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v1.1.1";
      flake = false;
    };

    # Unlike the three above, this is a real dependency of the shipped
    # `cl-cc-php` system (src/runtime-builtins-string-json.lisp's
    # `%php-json-validate` calls into it directly), not a test-only input —
    # see cl-cc-php.asd's `:depends-on`. Pinned to a release tag for the same
    # reason as the other siblings.
    cl-json-kit = {
      url = "github:nerima-lisp/cl-json-kit/v1.2.0";
      flake = false;
    };

    # Also a real dependency of the shipped system, added by the 2026-08-01
    # org-wide uiop -> cl-host-kit migration: src/runtime-builtins-io-files.lisp
    # (is_dir) and src/runtime-builtins-types.lisp (FILTER_VALIDATE_URL) call
    # into it. Declared `flake = false` and registered as a plain source tree
    # like every sibling above, rather than consumed as a flake package the way
    # cl-nix-forge-based repos in the org do it — this flake has no
    # `lispDependencies`; run-tests.lisp resolves dependencies itself.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      flake = false;
    };

    # `inputs.nixpkgs.follows` is mandatory on every input that is itself a
    # flake: without it each one drags in its own nixpkgs, inflating flake.lock
    # and rebuilding the same derivations. The sibling inputs above are all
    # `flake = false` (plain source trees with no inputs of their own), so
    # treefmt-nix is the only input that can carry a `follows`.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-cc-bootstrap,
      cl-cc-ast,
      cl-cc-parse,
      cl-cc-runtime,
      cl-cc-vm,
      cl-weave,
      cl-parser-kit,
      cl-regex-kit,
      cl-tty-kit,
      cl-log-kit,
      cl-process-kit,
      cl-codec-kit,
      cl-concurrent-kit,
      cl-boundary-kit,
      cl-date-kit,
      cl-json-kit,
      cl-host-kit,
      treefmt-nix,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Single source of truth for the package version: the `:version` form in
      # cl-cc-php.asd. A release only ever edits the .asd file and every Nix
      # package (default + docs) follows automatically. Nix regexes are
      # whole-string anchored and `.` never spans newlines, so the version is
      # extracted line-by-line rather than with one multi-line match.
      version =
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile ./cl-cc-php.asd);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match "[[:space:]]*:version \"[^\"]*\"" line != null) lines
          );
        in
        builtins.head (builtins.match "[[:space:]]*:version \"([^\"]*)\"" versionLine);

      # run-tests.lisp reads each dependency root from an env var so the Nix
      # derivation can hand in exact flake-input store paths. Shared verbatim by
      # checks.default and apps.test so the two cannot drift.
      testEnv = {
        CL_CC_PHP_CL_CC_BOOTSTRAP_ROOT = "${cl-cc-bootstrap}";
        CL_CC_PHP_CL_CC_AST_ROOT = "${cl-cc-ast}";
        CL_CC_PHP_CL_CC_PARSE_ROOT = "${cl-cc-parse}";
        CL_CC_PHP_CL_CC_RUNTIME_ROOT = "${cl-cc-runtime}";
        CL_CC_PHP_CL_CC_VM_ROOT = "${cl-cc-vm}";
        CL_CC_PHP_CL_WEAVE_ROOT = "${cl-weave}";
        CL_CC_PHP_CL_PARSER_KIT_ROOT = "${cl-parser-kit}";
        CL_CC_PHP_CL_REGEX_KIT_ROOT = "${cl-regex-kit}";
        CL_CC_PHP_CL_TTY_KIT_ROOT = "${cl-tty-kit}";
        CL_CC_PHP_CL_LOG_KIT_ROOT = "${cl-log-kit}";
        CL_CC_PHP_CL_PROCESS_KIT_ROOT = "${cl-process-kit}";
        CL_CC_PHP_CL_CODEC_KIT_ROOT = "${cl-codec-kit}";
        CL_CC_PHP_CL_CONCURRENT_KIT_ROOT = "${cl-concurrent-kit}";
        CL_CC_PHP_CL_BOUNDARY_KIT_ROOT = "${cl-boundary-kit}";
        CL_CC_PHP_CL_DATE_KIT_ROOT = "${cl-date-kit}";
        CL_CC_PHP_CL_JSON_KIT_ROOT = "${cl-json-kit}";
        CL_CC_PHP_CL_HOST_KIT_ROOT = "${cl-host-kit}";
      };

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: nixfmt (RFC-style) is a zero-footgun, low-diff
      # formatter, whereas YAML formatters mangle the GitHub Actions `on:` key
      # and Markdown reformatting would churn the whole docs tree.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          cl-cc-php = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-php";
            inherit version;
            src = self;
            nativeBuildInputs = [ pkgs.sbcl ];
            # The package artifact is the ASDF source tree; checks.default runs
            # the test system against it.
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/share/common-lisp/source/cl-cc-php"
              cp -R . "$out/share/common-lisp/source/cl-cc-php"
              runHook postInstall
            '';
            meta = {
              description = "CL-CC PHP frontend: lexer, parser, and grammar";
              homepage = "https://github.com/nerima-lisp/cl-cc-php";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.unix;
            };
          };
          default = cl-cc-php;

          # sb-cover HTML report over cl-cc-php's own source only (see
          # coverage.lisp's header for why the dependency/test-suite code is
          # loaded uninstrumented). This exists to make the number visible and
          # trending, not to gate CI on a percentage nobody has agreed to yet —
          # it is a package, not a check.
          coverage =
            pkgs.runCommand "cl-cc-php-coverage"
              (
                testEnv
                // {
                  nativeBuildInputs = [
                    pkgs.sbcl
                    pkgs.coreutils
                  ];
                }
              )
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                cp -R ${self} "$TMPDIR/src"
                chmod -R u+w "$TMPDIR/src"
                cd "$TMPDIR/src"
                # $out only exists once the builder runs, so it has to be
                # exported here rather than set as a derivation attribute
                # (which Nix would take as the literal two-character string
                # "$out", not a shell expansion of the real output path).
                export CL_CC_PHP_COVERAGE_OUT="$out"
                # Same hang-must-fail-loudly reasoning as checks.default, with a
                # longer budget: this force-recompiles cl-cc-php under
                # instrumentation before running the suite, which is slower than
                # a plain test run.
                timeout 900 sbcl --script coverage.lisp
                test -s "$out/cover-index.html"
              '';

          # Rendered documentation site (Material for MkDocs).
          # Build fully offline: Material for MkDocs bundles all of its assets,
          # so no network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-php-docs";
            inherit version;
            # Rooted at the repository, not at ./docs, so the config path passed
            # to mkdocs below is the same `docs/mkdocs.yml` a contributor types.
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            # Invoked from the repository root, hence `-f docs/mkdocs.yml`.
            buildPhase = ''
              runHook preBuild
              mkdocs build --strict -f docs/mkdocs.yml --site-dir "$out"
              runHook postBuild
            '';
            dontInstall = true;
            meta = {
              description = "Rendered MkDocs (Material) documentation for cl-cc-php";
              homepage = "https://github.com/nerima-lisp/cl-cc-php";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel, with
      # build caching. Add a check here rather than a job in ci.yml.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default =
            pkgs.runCommand "cl-cc-php-tests"
              (
                testEnv
                // {
                  nativeBuildInputs = [
                    pkgs.sbcl
                    pkgs.coreutils
                  ];
                }
              )
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                # Run tests from a writable copy of the source tree.
                cp -R ${self} "$TMPDIR/src"
                chmod -R u+w "$TMPDIR/src"
                cd "$TMPDIR/src"
                # Bound the test run so a hung runner cannot stall CI.
                timeout 600 sbcl --script run-tests.lisp
                touch "$out/passed"
              '';

          # Fails `nix flake check` when any tracked file is unformatted,
          # turning the formatter into an enforced CI gate.
          formatting = treefmtEval.${system}.config.build.check self;

          # The docs package builds with `mkdocs --strict`, so a broken link or
          # a page missing from the nav fails the build. Without this the docs
          # are only ever built by the publish workflow, which runs after a
          # merge to main, meaning such a break surfaces as a failed deploy
          # rather than as a failed pull request.
          docs = self.packages.${system}.docs;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = pkgs.writeShellApplication {
            name = "cl-cc-php-test";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              export CL_CC_PHP_CL_CC_BOOTSTRAP_ROOT="${cl-cc-bootstrap}"
              export CL_CC_PHP_CL_CC_AST_ROOT="${cl-cc-ast}"
              export CL_CC_PHP_CL_CC_PARSE_ROOT="${cl-cc-parse}"
              export CL_CC_PHP_CL_CC_RUNTIME_ROOT="${cl-cc-runtime}"
              export CL_CC_PHP_CL_CC_VM_ROOT="${cl-cc-vm}"
              export CL_CC_PHP_CL_WEAVE_ROOT="${cl-weave}"
              export CL_CC_PHP_CL_PARSER_KIT_ROOT="${cl-parser-kit}"
              export CL_CC_PHP_CL_REGEX_KIT_ROOT="${cl-regex-kit}"
              export CL_CC_PHP_CL_TTY_KIT_ROOT="${cl-tty-kit}"
              export CL_CC_PHP_CL_LOG_KIT_ROOT="${cl-log-kit}"
              export CL_CC_PHP_CL_PROCESS_KIT_ROOT="${cl-process-kit}"
              export CL_CC_PHP_CL_CODEC_KIT_ROOT="${cl-codec-kit}"
              export CL_CC_PHP_CL_CONCURRENT_KIT_ROOT="${cl-concurrent-kit}"
              export CL_CC_PHP_CL_BOUNDARY_KIT_ROOT="${cl-boundary-kit}"
              export CL_CC_PHP_CL_DATE_KIT_ROOT="${cl-date-kit}"
              export CL_CC_PHP_CL_JSON_KIT_ROOT="${cl-json-kit}"
              export CL_CC_PHP_CL_HOST_KIT_ROOT="${cl-host-kit}"
              # Run tests from a writable copy of the source tree.
              workdir="$(mktemp -d)"
              trap 'rm -rf "$workdir"' EXIT
              cp -R ${self}/. "$workdir"
              chmod -R u+w "$workdir"
              cd "$workdir"
              # Bound the test run so a hung runner cannot stall the command.
              exec timeout 600 sbcl --script run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-cc-php-test";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-cc-php-test";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell (
            testEnv
            // {
              packages = [ pkgs.sbcl ];
            }
          );
        }
      );
    };
}
