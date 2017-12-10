
#ifdef 	TESTDISVAL
float epsilon = 0.5e-4, valmax = 100;
if(valid_image[iblockima]){
	if (*(pscratch_0[iblockima]) > valmax && PSFDISVAL[0] > epsilon)
			printf("\u2465 NFZ0 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[0] %g scratch %g new_simus %12.5g \n",
				iblockima, iglobal, ithreads, PSFpos, ipixel[0], jpixel[0], tmp_0, PSFDISVAL[0], *(pscratch_0[iblockima]), NSIF_0[iblockima]);
	if (*(pscratch_1[iblockima]) > valmax && PSFDISVAL[1] > epsilon)
			printf("\u2465 NFZ1 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[3] %g scratch %g  new_simus %8.5f \n",
				iblockima, iglobal, ithreads, PSFpos, ipixel[1], jpixel[1], tmp_1, PSFDISVAL[1], *(pscratch_1[iblockima]), NSIF_1[iblockima]);
	if (*(pscratch_2[iblockima]) > valmax && PSFDISVAL[2] > epsilon)
			printf("\u2465 NFZ2 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[2] %g scratch %g  new_simus %8.5f \n",
					iblockima, iglobal, ithreads, PSFpos, ipixel[2], jpixel[2], tmp_2, PSFDISVAL[2], *(pscratch_2[iblockima]), NSIF_2[iblockima]);
	if (*(pscratch_3[iblockima]) > valmax && PSFDISVAL[3] > epsilon)
			printf("\u2465 NFZ3 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[3] %g scratch %g  new_simus %8.5f \n",
					iblockima, iglobal, ithreads, PSFpos, ipixel[3], jpixel[3], tmp_3, PSFDISVAL[3], *(pscratch_3[iblockima]), NSIF_3[iblockima]);
	}
			__syncthreads();
#endif
