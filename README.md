# FugiTech/FFMPEG

## Backstory

For several of my projects I need the ability to optimize images. Currently, AVIF is the most efficient format, and FFMPEG is the best way I've found to generate good AVIFs.

Sadly, installing a pre-built FFMPEG either doesn't support AVIF in the way I need, or uses outdated versions of the encoders. So it's best to build it from source.

Additionally, FFMPEG does not currently support decoding animated WEBP images. It also has issues encoding AVIF images with SVT-AV1 for images over 240fps. So I include a custom patch to fix both those problems.

## How to use

This repo is a simple Dockerfile and patch to FFMPEG so that I can generate an easy-to-use docker image containing an `ffmpeg` and `ffprobe` binary useful for optimizing images. I expect most production use cases will copy the binaries out into a more complete docker image.

However, you can also use it directly:

```bash
docker run --rm ghcr.io/fugitech/ffmpeg:latest -version
docker run --rm -v "$PWD:/work" -w /work ghcr.io/fugitech/ffmpeg:latest -i input.webp output.gif
docker run --rm --entrypoint ffprobe ghcr.io/fugitech/ffmpeg:latest -version
```

## Thanks

Obviously, thank you to FFMPEG.

Also thank you to Michael Ni, whose work I based most of the patch off of. You can view his original changes at https://code.ffmpeg.org/FFmpeg/FFmpeg/pulls/20568
