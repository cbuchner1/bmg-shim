# Fresh CachyOS verification image.  The installer installs every build
# dependency itself; this image only supplies a clean base.
FROM docker.io/cachyos/cachyos:latest
COPY patches/ /patches/
COPY install-cachyos.sh /install-cachyos.sh
RUN chmod +x /install-cachyos.sh
ENTRYPOINT ["/install-cachyos.sh"]
