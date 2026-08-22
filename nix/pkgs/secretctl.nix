{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "secretctl";
  version = "0.2.0";

  src = ../secretctl;
  vendorHash = "sha256-1Ssr9mK4/N1H/gF/wZOOYxOgmNt6YoOXiS3EbtmTkug=";
  proxyVendor = true;

  subPackages = [ "cmd/secretctl" ];

  postInstall = ''
    mkdir -p $out/libexec/secretctl
    substitute helpers/aws-credential-helper.sh $out/libexec/secretctl/aws-credential-helper \
      --replace-fail '@secretctl@' "$out/bin/secretctl"
    substitute helpers/kube-credential-helper.sh $out/libexec/secretctl/kube-credential-helper \
      --replace-fail '@secretctl@' "$out/bin/secretctl"
    chmod 755 $out/libexec/secretctl/aws-credential-helper
    chmod 755 $out/libexec/secretctl/kube-credential-helper
  '';

  meta = {
    description = "Agent-safe, provider-neutral secret manager frontend";
    license = lib.licenses.mit;
    mainProgram = "secretctl";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
