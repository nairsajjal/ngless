{ mkDerivation, aeson, ansi-terminal, async, base, bytestring
, bzlib, bzlib-conduit, conduit, conduit-combinators, conduit-extra
, configurator, containers, convertible, data-default, deepseq
, directory, double-conversion, edit-distance, errors, extra
, file-embed, filemanip, filepath, hashable, hashtables
, http-client, http-conduit, HUnit, IntervalMap, MissingH, mtl
, network, old-locale, optparse-applicative, parallel, parsec
, primitive, process, QuickCheck, random, resourcet, stdenv, stm
, stm-chans, stm-conduit, strict, tar, template-haskell
, test-framework, test-framework-hunit, test-framework-quickcheck2
, test-framework-th, text, time, transformers, unix, vector
, vector-algorithms, yaml, zlib
# , fetchurl
, fetchFromGitHub
, makeWrapper
, pkgs
}:
mkDerivation {
  pname = "NGLess";
  version = "0.0.0";
  src = fetchFromGitHub {
    owner = "luispedro";
    repo = "ngless";
    rev = "e5591a9084bdb45fdf5583cb47edd7bec1a6c9fb";
    sha256 = "1g1fli2ihkfnnjsvdygc50kqncmrw1yajy6ph8x9brzr4wblcpn8";
  };
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson ansi-terminal async base bytestring bzlib bzlib-conduit
    conduit conduit-combinators conduit-extra configurator containers
    convertible data-default deepseq directory double-conversion
    edit-distance errors extra file-embed filemanip filepath hashable
    hashtables http-client http-conduit IntervalMap MissingH mtl
    network old-locale optparse-applicative parallel parsec primitive
    process random resourcet stm stm-chans stm-conduit strict tar
    template-haskell text time transformers unix vector
    vector-algorithms yaml zlib
    pkgs.wget
    pkgs.m4
    pkgs.samtools
    pkgs.bwa
    makeWrapper
  ];
  testHaskellDepends = [
    aeson ansi-terminal async base bytestring bzlib bzlib-conduit
    conduit conduit-combinators conduit-extra configurator containers
    convertible data-default deepseq directory double-conversion
    edit-distance errors extra file-embed filemanip filepath hashable
    hashtables http-client http-conduit HUnit IntervalMap MissingH mtl
    network old-locale optparse-applicative parallel parsec primitive
    process QuickCheck random resourcet stm stm-chans stm-conduit
    strict tar template-haskell test-framework test-framework-hunit
    test-framework-quickcheck2 test-framework-th text time transformers
    unix vector vector-algorithms yaml zlib
  ];
  configureFlags = "-f-embed";
  license = stdenv.lib.licenses.mit;

  preConfigure = ''
    m4 NGLess.cabal.m4 > NGLess.cabal
  '';

  postBuild = ''
    make modules
  '';

  postInstall = ''
    mkdir -p $out/share/ngless/data
    mkdir -p $out/share/ngless/bin
    cp -pr Modules $out/share/ngless/data
    wrapProgram $out/bin/ngless \
        --set NGLESS_SAMTOOLS_BIN ${pkgs.samtools}/bin/samtools \
        --set NGLESS_BWA_BIN ${pkgs.bwa}/bin/bwa
  '';
}
