{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/xmltv";
  guideFile = "${stateDir}/guide.xml";
  cacheFile = "${stateDir}/sdjson.cache";
  guideDays = 14;

  programIdLine = "push(@result, [ $program->{'programID'}, 'dd_progid' ]);";
  airDateEpisodeForGenericShows = ''
    if(!(length($season) || length($episode) || length($part)) && $program->{'programID'} =~ /^SH/) {
    		my @airdate = localtime(parse_airtime($program->{'airDateTime'}));
    		push(@result, [ sprintf('.%d.', sprintf('%04d%02d%02d', $airdate[5] + 1900, $airdate[4] + 1, $airdate[3]) - 1), 'xmltv_ns' ]);
    	}
    	${programIdLine}'';

  xmltv = pkgs.perlPackages.buildPerlPackage {
    pname = "xmltv";
    version = "1.4.0";
    src = pkgs.fetchFromGitHub {
      owner = "XMLTV";
      repo = "xmltv";
      tag = "v1.4.0";
      hash = "sha256-edfg18E8BSBZy5OVL0T5F/SmNiSlbHZeQH/a9XCSDnE=";
    };
    postPatch = ''
      substituteInPlace t/test_tv_imdb.t --replace-fail "/bin/cp" "${pkgs.coreutils}/bin/cp"
      substituteInPlace grab/zz_sdjson/tv_grab_zz_sdjson \
        --replace-fail ${lib.escapeShellArg programIdLine} ${lib.escapeShellArg airDateEpisodeForGenericShows}
    '';
    makeMakerFlags = [ "--components=tv_grab_zz_sdjson" ];
    doInstallCheck = true;
    installCheckPhase = ''
      export HOME="$TMPDIR"
      $out/bin/tv_grab_zz_sdjson --version
    '';
    propagatedBuildInputs = with pkgs.perlPackages; [
      DateManip
      FileSlurp
      JSON
      HTTPMessage
      LWP
      LWPProtocolHttps
      TermReadKey
      URI
      XMLLibXML
      XMLParser
      XMLTreePP
      XMLTwig
      XMLWriter
      DateTime
      TryTiny
    ];
  };
in
{
  users = {
    groups.xmltv = { };
    users.xmltv = {
      isSystemUser = true;
      group = "xmltv";
      home = stateDir;
    };
  };

  sops.secrets = {
    "schedules-direct/username" = { };
    "schedules-direct/password" = { };
    "schedules-direct/lineup" = { };
  };

  sops.templates."tv_grab_zz_sdjson.conf".content = ''
    cache=${cacheFile}
    channel-id-format=default
    previously-shown-format=date
    username=${config.sops.placeholder."schedules-direct/username"}
    password=${config.sops.placeholder."schedules-direct/password"}
    mode=lineup
    lineup=${config.sops.placeholder."schedules-direct/lineup"}
  '';

  systemd.services.xmltv = {
    description = "Fetch TV guide from Schedules Direct";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = stateDir;
    serviceConfig = {
      Type = "oneshot";
      User = "xmltv";
      Group = "xmltv";
      StateDirectory = "xmltv";
      StateDirectoryMode = "0755";
      UMask = "0022";
      LoadCredential = "config:${config.sops.templates."tv_grab_zz_sdjson.conf".path}";
      ExecStart = "${xmltv}/bin/tv_grab_zz_sdjson --config-file %d/config --days ${toString guideDays} --quiet --output ${guideFile}.new";
      ExecStartPost = "${pkgs.coreutils}/bin/mv ${guideFile}.new ${guideFile}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  systemd.timers.xmltv = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
