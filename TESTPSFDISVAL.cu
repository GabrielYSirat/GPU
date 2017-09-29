
#ifdef 	TESTDISVAL
if(valid_image[iblockima]){
	if ((PSFDISVAL[0] * tmp_0  > DD.expectedmax * 8500))// 50% max PSF
			printf("\u2465 NFZ0 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[0] %g  new_simus %8.5f \n", 
				iblockima, iglobal, ithreads, PSFpos, ipixel[0], jpixel[0], tmp_0, PSFDISVAL[0], new_simu_inregister_float_0[iblockima]);
	if ((PSFDISVAL[1] * tmp_1  > DD.expectedmax * 8500))// 50% max PSF
			printf("\u2465 NFZ1 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[3] %g  new_simus %8.5f \n",
				iblockima, iglobal, ithreads, PSFpos, ipixel[1], jpixel[1], tmp_1, PSFDISVAL[1], new_simu_inregister_float_1[iblockima]);
	if ((PSFDISVAL[2] * tmp_2  > DD.expectedmax * 8500))// 50% max PSF
			printf("\u2465 NFZ2 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[2] %g  new_simus %8.5f \n",
					iblockima, iglobal, ithreads, PSFpos, ipixel[2], jpixel[2], tmp_2, PSFDISVAL[2], new_simu_inregister_float_2[iblockima]);
	if ((PSFDISVAL[3] * tmp_3  > DD.expectedmax * 8500))// 50% max PSF
			printf("\u2465 NFZ3 iblockima %d iglobal %d ithreads %d PSFpos %d  ipixel %d jpixel %d val %g PSFDISVAL[3] %g  new_simus %8.5f \n",
				iblockima, iglobal, ithreads, PSFpos, ipixel[3], jpixel[3], tmp_3, PSFDISVAL[3], new_simu_inregister_float_3[iblockima]);
	}
			__syncthreads();
#endif
