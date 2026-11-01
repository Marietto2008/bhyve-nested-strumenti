/* --- amd64/vmm/vmm_instruction_emul.c:275 */
static uint64_t size2mask[] = {
	[1] = 0xff,
	[2] = 0xffff,
	[4] = 0xffffffff,
	[8] = 0xffffffffffffffff,
};

/* --- amd64/vmm/vmm_instruction_emul.c:1882 */
uint64_t
vie_size2mask(int size)
{
	KASSERT(size == 1 || size == 2 || size == 4 || size == 8,
	    ("vie_size2mask: invalid size %d", size));
	return (size2mask[size]);
}

/* --- amd64/vmm/vmm_instruction_emul.c:1890 */
int
vie_calculate_gla(enum vm_cpu_mode cpu_mode, enum vm_reg_name seg,
    struct seg_desc *desc, uint64_t offset, int length, int addrsize,
    int prot, uint64_t *gla)
{
	uint64_t firstoff, low_limit, high_limit, segbase;
	int glasize, type;

	KASSERT(seg >= VM_REG_GUEST_ES && seg <= VM_REG_GUEST_GS,
	    ("%s: invalid segment %d", __func__, seg));
	KASSERT(length == 1 || length == 2 || length == 4 || length == 8,
	    ("%s: invalid operand size %d", __func__, length));
	KASSERT((prot & ~(PROT_READ | PROT_WRITE)) == 0,
	    ("%s: invalid prot %#x", __func__, prot));

	firstoff = offset;
	if (cpu_mode == CPU_MODE_64BIT) {
		KASSERT(addrsize == 4 || addrsize == 8, ("%s: invalid address "
		    "size %d for cpu_mode %d", __func__, addrsize, cpu_mode));
		glasize = 8;
	} else {
		KASSERT(addrsize == 2 || addrsize == 4, ("%s: invalid address "
		    "size %d for cpu mode %d", __func__, addrsize, cpu_mode));
		glasize = 4;
		/*
		 * If the segment selector is loaded with a NULL selector
		 * then the descriptor is unusable and attempting to use
		 * it results in a #GP(0).
		 */
		if (SEG_DESC_UNUSABLE(desc->access))
			return (-1);

		/*
		 * The processor generates a #NP exception when a segment
		 * register is loaded with a selector that points to a
		 * descriptor that is not present. If this was the case then
		 * it would have been checked before the VM-exit.
		 */
		KASSERT(SEG_DESC_PRESENT(desc->access),
		    ("segment %d not present: %#x", seg, desc->access));

		/*
		 * The descriptor type must indicate a code/data segment.
		 */
		type = SEG_DESC_TYPE(desc->access);
		KASSERT(type >= 16 && type <= 31, ("segment %d has invalid "
		    "descriptor type %#x", seg, type));

		if (prot & PROT_READ) {
			/* #GP on a read access to a exec-only code segment */
			if ((type & 0xA) == 0x8)
				return (-1);
		}

		if (prot & PROT_WRITE) {
			/*
			 * #GP on a write access to a code segment or a
			 * read-only data segment.
			 */
			if (type & 0x8)			/* code segment */
				return (-1);

			if ((type & 0xA) == 0)		/* read-only data seg */
				return (-1);
		}

		/*
		 * 'desc->limit' is fully expanded taking granularity into
		 * account.
		 */
		if ((type & 0xC) == 0x4) {
			/* expand-down data segment */
			low_limit = desc->limit + 1;
			high_limit = SEG_DESC_DEF32(desc->access) ?
			    0xffffffff : 0xffff;
		} else {
			/* code segment or expand-up data segment */
			low_limit = 0;
			high_limit = desc->limit;
		}

		while (length > 0) {
			offset &= vie_size2mask(addrsize);
			if (offset < low_limit || offset > high_limit)
				return (-1);
			offset++;
			length--;
		}
	}

	/*
	 * In 64-bit mode all segments except %fs and %gs have a segment
	 * base address of 0.
	 */
	if (cpu_mode == CPU_MODE_64BIT && seg != VM_REG_GUEST_FS &&
	    seg != VM_REG_GUEST_GS) {
		segbase = 0;
	} else {
		segbase = desc->base;
	}

	/*
	 * Truncate 'firstoff' to the effective address size before adding
	 * it to the segment base.
	 */
	firstoff &= vie_size2mask(addrsize);
	*gla = (segbase + firstoff) & vie_size2mask(glasize);
	return (0);
}

