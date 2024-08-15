title: perf

date: 2024-05-10 10:09:00

tags:

categories: dbg_meth

---

tar -xvf perf-5.10.0.tar.gz 
cd perf-5.10.0
cd tools/perf/
make
sudo cp perf /usr/local/bin

/usr/local/bin/perf --version

download:
	https://cdn.kernel.org/pub/linux/kernel/tools/perf/