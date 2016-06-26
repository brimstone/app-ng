PCD_VERSION := 0.3

ifdef WITH_DOCKER
.DEFAULT_GOAL := docker
.PHONY: docker_image docker
docker_image:
	docker build -t pcd:${PCD_VERSION} . >&2

docker: docker_image
	@echo "Building with docker"
	docker run --rm -i pcd:${PCD_VERSION} make tar | tar -xC output

docker_debug: docker_image
	docker run --rm -it pcd:${PCD_VERSION}
endif

.PHONY: all
all: kernel.gz components out cpio

kernel.gz:
	@echo "Building kernel" >&2
	@cd kernel && make >&2
	@cp kernel/kernel.gz . >&2

libc:
	@cd musl && make >&2

.PHONY: components
components: libc
	@cd busybox && make >&2

out: kernel.gz components
	@echo "Extracting compiled modules to output directory" >&2
	@mkdir -p out/dev/pts >&2
	@mknod out/dev/console c 5 1 >&2
	@# TODO loop over every directory in $PWD
	@tar -xf kernel/*.tar -C out >&2
	@tar -xf busybox/*.tar -C out >&2

initrd: out
	@echo "Building initrd" >&2
	@cd out && find . | cpio --create --format='newc' > ../initrd

initrd.xz: initrd
	@echo "Compressing initrd" >&2
	@xz --check=crc32 -9 --keep initrd >&2

.PHONY: tar	
tar: initrd.xz
	@echo "Extracting output files" >&2
	@tar -cf - kernel.gz initrd.xz 
	@echo "Export complete" >&2

.PHONY: clean
clean:
	-rm initrd.xz
	-rm kernel.gz
	-rm out.tar

