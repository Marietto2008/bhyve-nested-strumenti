#pragma D option quiet
BEGIN
{
	printf("sizeof dpcpu_off=%d  elemento=%d\n", sizeof(kernel`dpcpu_off), sizeof(kernel`dpcpu_off[0]));
	printf("dpcpu_off[0..7] come uintptr_t*: %x %x %x %x %x %x %x %x\n",
	    ((uintptr_t *)&kernel`dpcpu_off)[0], ((uintptr_t *)&kernel`dpcpu_off)[1], ((uintptr_t *)&kernel`dpcpu_off)[2], ((uintptr_t *)&kernel`dpcpu_off)[3],
	    ((uintptr_t *)&kernel`dpcpu_off)[4], ((uintptr_t *)&kernel`dpcpu_off)[5], ((uintptr_t *)&kernel`dpcpu_off)[6], ((uintptr_t *)&kernel`dpcpu_off)[7]);
	printf("&pcpu_entry_cc_cpu=%p  mp_ncpus=%d  tidhash=%x  sizeof tidhashtbl=%d  tidhashtbl=%p\n",
	    &kernel`pcpu_entry_cc_cpu, kernel`mp_ncpus, kernel`tidhash, sizeof(kernel`tidhashtbl), (void *)kernel`tidhashtbl);
	printf("timehands=%p  sizeof *timehands=%d\n", (void *)kernel`timehands, sizeof(*kernel`timehands));
	exit(0);
}
