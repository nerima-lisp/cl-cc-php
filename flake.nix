{
  description = "cl-cc-php: PHP frontend (lexer, parser, grammar, runtime builtins) for the cl-cc Common Lisp compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # cl-cc-php depends on cl-cc-ast/cl-cc-bootstrap/cl-cc-parse/cl-cc-vm, and
    # its e2e test suite additionally needs cl-cc-pipeline to compile and run
    # PHP source end-to-end. bootstrap/vm/parse are the compiler's
    # self-referential core (see cl-cc's docs/repo-split-design.md — they are
    # explicitly a non-goal for further splitting), so unlike a dependency-free
    # leaf (cl-cc-ast) this system pulls its dependencies out of a checkout of
    # the whole monorepo rather than from independently split repos.
    cl-cc = {
      url = "github:nerima-lisp/cl-cc";
      flake = false;
    };
    # Test-only: cl-weave is the test framework cl-cc-php/tests runs on
    # directly. cl-prolog and cl-parser-kit are, in turn, cl-cc-optimize's
    # own dependencies (part of the transitive closure cl-cc-pipeline pulls
    # in for the e2e suites) — pulled the same way cl-cc's own flake pulls
    # them, as plain source trees built by cl-cc-php's own ASDF source
    # registry rather than as flakes (see scripts/run-tests.lisp).
    cl-weave = {
      url = "github:nerima-lisp/cl-weave";
      flake = false;
    };
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog";
      flake = false;
    };
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit";
      flake = false;
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
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs systems (system: function (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.sbcl ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      packages = forAllSystems (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "cl-cc-php";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ pkgs.sbcl ];
          # No dependency-free compile check is possible (see README's Status
          # section) — the lightest verifiable build artifact is the source
          # tree itself, exactly as cl-cc-ast's own `default` package does.
          installPhase = ''
            mkdir -p "$out/share/common-lisp/source/cl-cc-php"
            cp -R . "$out/share/common-lisp/source/cl-cc-php"
          '';
          meta = {
            description = "CL-CC PHP frontend: lexer, parser, and grammar";
            homepage = "https://github.com/nerima-lisp/cl-cc-php";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.unix;
          };
        };
      });

      checks = forAllSystems (pkgs: {
        test = pkgs.stdenvNoCC.mkDerivation {
          name = "cl-cc-php-test";
          src = self;
          nativeBuildInputs = [ pkgs.sbcl ];
          buildPhase = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            export CL_CC_PHP_CL_CC_ROOT="${toString cl-cc}"
            export CL_CC_PHP_CL_WEAVE_ROOT="${toString cl-weave}"
            export CL_CC_PHP_CL_PROLOG_ROOT="${toString cl-prolog}"
            export CL_CC_PHP_CL_PARSER_KIT_ROOT="${toString cl-parser-kit}"
            sbcl --script scripts/run-tests.lisp
          '';
          installPhase = "touch $out";
        };
      });
    };
}
