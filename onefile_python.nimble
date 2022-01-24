# Package

version       = "0.1.0"
author        = "Simon Pinfold"
description   = "Run python from a single exe"
license       = "ISC"
bin           = @["onefile_python"]

# Dependencies

requires "nim >= 1.6.2"
requires "https://github.com/synap5e/memlib.git"  # Use fork while https://github.com/khchen/memlib/pull/3 is not merged
requires "zippy >= 0.7.3"
requires "nimpy >= 0.2.0"

task build, "Build":
    exec "nim -d:release c onefile_python.nim"