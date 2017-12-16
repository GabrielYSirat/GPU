#ifdef PSCRATCHTEST
			if ((ipixel[3] == PSFZoomo2) && (jpixel[3] == PSFZoomo2))
				if (image_to_scratchpad_offset_tile[iblockima]!= (DD.defaultoffsetedge)) {
					printf("\u2465 ipix jpix = iPSF jPSF zero ithreads %d 4:%d offset %d value %g \n", ithreads, pos_3,
							image_to_scratchpad_offset_tile[iblockima], *(Scratchpad + pos_3));
					printf("\u2465 values of pointer position pscratch iblockima %d: %p 2: %p 3: %p 4:%p \n", iblockima,
							*(pscratch_0 + iblockima), *(pscratch_1 + iblockima), *(pscratch_2 + iblockima),
							*(pscratch_3 + iblockima));
				 }

			if (!iblockima)
				if ((*pscratch_0[iblockima] + *pscratch_1[iblockima] + *pscratch_2[iblockima] + *pscratch_3[iblockima])
						> 0.01)// max PSF *5%
					printf(
							"\u2465 NEZ ithreads %d ipixel %d jpixel %d pos %d %d %d %d  *pscratch %6.3f %6.3f %6.3f %6.3f\n",
							ithreads, ipixel[3], jpixel[3], pos_0, pos_1, pos_2, pos_3, *pscratch_0[iblockima],
							*pscratch_1[iblockima], *pscratch_2[iblockima], *pscratch_3[iblockima]);

			__syncthreads();
#endif
