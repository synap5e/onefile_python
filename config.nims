
--gc:orc
--define:windows
when defined(release):
  --define:danger
  --passL:"-Wl,--gc-sections,-flto,-s"  # gc sections, strip, link-time optimization
  --passC:"-flto"  # link-time optimization
  --opt:size

