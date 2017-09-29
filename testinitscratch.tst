#ifdef TESTINITSCRATCH
	for (int iblockima = 0; iblockima < NIMAGESPARALLEL; iblockima++, iglobal++) {
			if (!iprint)
				if(!iblockima) printf("\n\u2465************************DEVICE:  SCRATCHPAD OFFSET ********************\n");
			if (!ithreads)
			printf("DEVICE: \u2465 SCRATCHPAD OFFSET : position %d pixel block index  %d"
					" image block index %d pscratch value %d\n", iblockima, pscratch_0[iblockima]);
			if (!iprint)
				if(iblockima == NIMAGESPARALLEL)
					printf("\u2465************************DEVICE:  SCRATCHPAD OFFSET ********************\n");
			__syncthreads();
#endif
