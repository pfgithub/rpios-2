https://isometimes.github.io/rpi4-osdev

follow that

then start reusing zigos/ code

just copying at first b/c I want to get it working and then start rewriting in zig

I don't have a way to read the uart stuff so I can't test without a screen

https://github.com/kumaashi/RaspberryPI/tree/master/RPI4

check this out for videocore iv graphics acceleration stuff

elm chan fatfs

try to make a kernel that allows selecting which kernel to boot from

basically: mount as readonly, copy the selected kernel image into memory (make sure to move the running program somewhere else in memory so it doesn't get overwritten)
