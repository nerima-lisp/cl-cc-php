{
  description = "cl-cc-php: PHP frontend (lexer, parser, grammar, runtime builtins) for the cl-cc Common Lisp compiler";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-cc-php depends on cl-cc-ast/cl-cc-bootstrap/cl-cc-parse/cl-cc-vm, and
    # its e2e test suite additionally needs cl-cc-pipeline to compile and run
    # PHP source end-to-end. bootstrap/vm/parse are the compiler's
    # self-referential core (see cl-cc's docs/repo-split-design.md — they are
    # explicitly a non-goal for further splitting), so unlike a dependency-free
    # leaf (cl-cc-ast) this system pulls its dependencies out of a checkout of
    # the whole monorepo rather than from independently split repos.
    #
    # Pinned to a commit, not a tag, unlike every other sibling below. cl-cc's
    # only tag is v0.1.0, which predates the packages/ split this repository
    # loads from, and it cannot cut a new one yet: its own `nix flake check`
    # fails with 55 failures and 31 errors. Those are not new — its pre-
    # migration check only ran the cl-cc-prolog-tools sub-suite, so the main
    # suite had never been wired to the gate at all.
    #
    # A commit is as immutable as a tag, which is what the pinning rule is
    # actually for; a bare `github:nerima-lisp/cl-cc` follows the default
    # branch and would break this repository on an unrelated upstream push.
    # Move to `/vX.Y.Z` once cl-cc's suite is green and it releases.
    cl-cc = {
      url = "github:nerima-lisp/cl-cc/594456c6671356508a9393a97761be41e4ef8f1f";
      flake = false;
    };

    # Test-only: cl-weave is the test framework t/ runs on directly. cl-prolog
    # and cl-parser-kit are, in turn, cl-cc-optimize's own dependencies (part of
    # the transitive closure cl-cc-pipeline pulls in for the e2e suites) —
    # pulled the same way cl-cc's own flake pulls them, as plain source trees
    # built by cl-cc-php's own ASDF source registry rather than as flakes (see
    # run-tests.lisp).
    #
    # These three are pinned to release tags: a bare github:nerima-lisp/<name>
    # follows that repo's default branch, so an upstream push to main would
    # break this repo's CI without warning.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.0.0";
      flake = false;
    };
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.0.1";
      flake = false;
    };
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit/v1.0.0";
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
      cl-cc,
      cl-weave,
      cl-prolog,
      cl-parser-kit,
      treefmt-nix,
    }:
    let
      # x86_64-linux is verified by CI; aarch64-darwin is verified by every
      # maintainer `nix flake check` on the development machine. aarch64-linux
      # and x86_64-darwin are deliberately not declared because nothing
      # verifies them (ADR-0078).
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
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
        CL_CC_PHP_CL_CC_ROOT = "${cl-cc}";
        CL_CC_PHP_CL_WEAVE_ROOT = "${cl-weave}";
        CL_CC_PHP_CL_PROLOG_ROOT = "${cl-prolog}";
        CL_CC_PHP_CL_PARSER_KIT_ROOT = "${cl-parser-kit}";
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
            # No dependency-free compile check is possible (see README's Status
            # section) — the lightest verifiable build artifact is the source
            # tree itself, exactly as cl-cc-ast's own `default` package does.
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

          # Rendered documentation site (Material for MkDocs).
          # Build fully offline: Material for MkDocs bundles all of its assets,
          # so no network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-php-docs";
            inherit version;
            # Rooted at the repository, not at ./docs, and CHANGELOG.md is part
            # of the fileset: docs/src/changelog.md is a one-line
            # `--8<-- "CHANGELOG.md"` snippet include rather than a duplicate of
            # the changelog, and pymdownx.snippets resolves it against
            # base_path ["."] — the directory mkdocs is invoked from.
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
                ./CHANGELOG.md
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            # Invoked from the repository root, hence `-f docs/mkdocs.yml`.
            # Running `cd docs && mkdocs ...` instead would put base_path at
            # docs/, and the CHANGELOG include would fail under check_paths.
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
                # run-tests.lisp registers the working directory as an ASDF
                # source tree, and the CLI-compile-path suite writes a .cache/
                # directory next to it, so the suite needs a WRITABLE copy of
                # the tree. Running it straight out of the read-only store path
                # fails with "Can't create directory .../.cache".
                cp -R ${self} "$TMPDIR/src"
                chmod -R u+w "$TMPDIR/src"
                cd "$TMPDIR/src"
                sbcl --script run-tests.lisp
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
              export CL_CC_PHP_CL_CC_ROOT="${cl-cc}"
              export CL_CC_PHP_CL_WEAVE_ROOT="${cl-weave}"
              export CL_CC_PHP_CL_PROLOG_ROOT="${cl-prolog}"
              export CL_CC_PHP_CL_PARSER_KIT_ROOT="${cl-parser-kit}"
              # Same reason as checks.default: the suite writes .cache/ relative
              # to the working directory, so it needs a writable tree rather
              # than the read-only store path.
              workdir="$(mktemp -d)"
              trap 'rm -rf "$workdir"' EXIT
              cp -R ${self}/. "$workdir"
              chmod -R u+w "$workdir"
              cd "$workdir"
              exec sbcl --script run-tests.lisp
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
