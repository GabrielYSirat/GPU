/*
 * RSVReconstruction.cu
 *
 *  Created on: Jul 8, 2017
 *      Author: gabriel
 */
#include "0_NewLoop.h"
std::string filenameimage;
std::string RECFILE = "image_iteration_0__63x114_4em";
std::string endREC = ".raw";



void Recprepare(void) {
	float MaxRec = 0.0f, SumRec = 0.0f;
	cudaMallocManaged(&original_rec, TA.reconstruction_size * sizeof(float)); // on device with a shadow on host
	cudaMallocManaged(&double_rec, TA.reconstruction_size * sizeof(double)); // on device with a shadow on host

	char * memblock;
	int size;

	filenameimage = resourcesdirectory + RECFILE + endREC;
	printf("REC \u24FC reconstruction image:  %s \n", filenameimage.c_str());

	/** *****************************data arrays allocation*********************************/
	/** original_reconstruction data in float stored on device with a shadow copy on host
	 *  double_rec data in double read from the file
	 *  i_reconstruction normalized data in char on host for image display
	 */


	//read reconstruction raw file
	std::ifstream RecFile(filenameimage.c_str(), ios::in | ios::binary | ios::ate);
	size = (RecFile.tellg()); 	// the data is stored in float of 4 bytes in the file
	size -= byte_skipped; 	// WE REMOVE byte_skipped BYTES
	std::cout << "REC \u24FC ************file read: size reconstruction in bytes = " << size << endl;
	memblock = new char[size];
	RecFile.seekg(byte_skipped, ios::beg); // byte_skipped first bytes are skipped
	RecFile.read(memblock, size);
	RecFile.close();
	std::cout << "REC \u24FC *******complete size  " << TA.reconstruction_size << "  Size in Bytes " << TA.reconstruction_size * sizeof(double) << endl;

	/** read reconstruction data from file in double, transfer to float on the global memory of the device and create a normalized image
	 *
	 */
	double_rec = (double*) memblock; //reinterpret the chars stored in the file as float
	for (int i = 0; i < TA.reconstruction_size; i++) {
		*(original_rec + i) = *(double_rec + i);
		SumRec += *(original_rec + i);
		MaxRec = max(*(original_rec + i), MaxRec);
	}	// sanity check, check max and sum


	std::cout << "REC \u24FC ***  max =" << MaxRec << "  Sum =" << SumRec << endl;
	const char * reconstructionImagefile = "results/reconstruction.pgm";
	unsigned char *i_reconstruction = (unsigned char *) calloc(TA.reconstruction_size, sizeof(unsigned char)); // on host
	double* double_rec = (double*) std::malloc(TA.reconstruction_size * sizeof(double)); // on host
	// write reconstruction image to disk /////////////////////////////////
	for (int i = 0; i < TA.reconstruction_size; i++) i_reconstruction[i] = 255.0 * original_rec[i] / MaxRec;			// image value

	printf("REC \u24FC Path to reconstruction original %s .....\n", reconstructionImagefile);
	sdkSavePGM(reconstructionImagefile, i_reconstruction, TA.Nb_Cols_reconstruction, TA.Nb_Rows_reconstruction);
	free(i_reconstruction);
	free(double_rec);
}

bool Recvalidate_host(void) {
	bool testrec;
	float MaXTile = 0.0f, Sum3rec = 0.0f, max3rec = 0.0f;

	// write rec in memory and validate
	unsigned char *i_rec = (unsigned char *) calloc(TA.reconstruction_size, sizeof(unsigned char)); // on host
	cudaMallocManaged(&val_rec, TA.reconstruction_size * sizeof(float));
	const char * recValImagefile = "results/recValImage.pgm";

	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the rec kernel
	Recvalidate_device<<<dimGrid, dimBlock, 0>>>(TA.Nb_Rows_reconstruction, TA.Nb_Cols_reconstruction);
	cudaDeviceSynchronize();

	for (int row = 0; row < TA.Nb_Rows_reconstruction; row++)
		for (int col = 0; col < TA.Nb_Cols_reconstruction; col++) {
			int tempr = row * TA.Nb_Cols_reconstruction + col;
			Sum3rec += *(val_rec + tempr);
			max3rec = max(max3rec, *(val_rec + tempr));
		}
	printf("on host: Sum3rec  %f max3rec %f   ", Sum3rec, max3rec);

	// write rec image validation to disk
	/////////////////////////////////
	MaXTile = 0.0f;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int i = 0; i < TA.reconstruction_size; i++) {
			MaXTile = max(MaXTile, val_rec[i]); // sanity check, check max
		}
	std::cout << "max device =" << MaXTile << "\n";
	for (int i = 0; i < TA.reconstruction_size; i++){
		i_rec[i] = 255.0 * val_rec[i] / MaXTile;			// Validation image value
	if(VERBOSE)
		if(i_rec[i] > 1)
	printf("i %d, col %d x %d y %d\n", i, TA.Nb_Cols_reconstruction, i % TA.Nb_Cols_reconstruction, i / TA.Nb_Cols_reconstruction);
	}
	printf("REC \u24FC Path to rec validation %s .....\n", recValImagefile);

	sdkSavePGM(recValImagefile, i_rec, TA.Nb_Cols_reconstruction, TA.Nb_Rows_reconstruction);

	printf("REC \u24FC Comparing files ... ");
	testrec = compareData(val_rec, original_rec, TA.reconstruction_size, MAX_EPSILON_ERROR, 0.15f);

	for (int jrec = 0; jrec < TA.reconstruction_size; jrec++) {
		Sumdel[1] += fabsf(*(val_rec + jrec) - *(original_rec + jrec));
	}
	printf("Sumdel[1] %f  ", Sumdel[1]);
	std::cout << "testrec = " << testrec << "\n";


	cudaFree(val_rec);
	return (testrec);
}

void Scratchprepare(void) {
	float Maxscratch = 0.0f, Sumscratch = 0.0f, maxTile = 0.0f, SumTile = 0.0f;

	const char * rectilereconstructionfile = "results/tilerec.pgm";
	const char * scratchpadImagefile = "results/scratchpad.pgm";

	float *tile_rec = (float*) std::calloc(ATile * tile.NbTileXY , sizeof(float)); 					// on host
	unsigned char *i_tilerec = (unsigned char *) calloc(ATile * tile.NbTileXY, sizeof(unsigned char));// on host
	cudaMallocManaged(&scratchpad_matrix, tile.NbTileXY * ASCRATCH * sizeof(float));
	unsigned char *i_scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH, sizeof(unsigned char)); // on host

/***********************************TILE RECONSTRUCTION ************************/
	printf("TILE \u24FC Path to tile reconstruction  %s .....", rectilereconstructionfile);

	int deltilex = tile.NbTilex * XTile - TA.Nb_Cols_reconstruction;
	int deltiley = tile.NbTiley * YTile - TA.Nb_Rows_reconstruction;
	printf(" offset = - del /2 !! x %d  y  %d\n", deltilex/2,deltiley/2);

	for (int arg = 0; arg < TA.reconstruction_size; arg++) {
		maxTile = max(maxTile,*(original_rec + arg));
		SumTile += *(original_rec + arg);
	}
	Maxscratch = maxTile; Sumscratch = SumTile;
	printf("TILE \u24FC maxTile %f SumTile %f\n",maxTile, SumTile);

	for (int row = 0; row < TA.Nb_Rows_reconstruction; row++)
		for (int col = 0; col < TA.Nb_Cols_reconstruction; col++) {
			int itemp = col + deltilex / 2 + (row + deltiley / 2) * tile.NbTilex * XTile;
			int itemp2 = col +  row  * TA.Nb_Cols_reconstruction;
			*(tile_rec + itemp) = *(original_rec + itemp2);
			i_tilerec[itemp] = 255. * *(tile_rec + itemp) / maxTile;
			if(VERBOSE)
				if(i_tilerec[itemp] > 1)
			printf("itemp %d, col %d x %d y %d\n", itemp, XTile*tile.NbTilex, itemp % (XTile*tile.NbTilex), itemp / (XTile*tile.NbTilex));

		}

	sdkSavePGM(rectilereconstructionfile, i_tilerec, XTile*tile.NbTilex, YTile * tile.NbTiley);

	// write scratchpad matrix to disk

	for (int iy = 0; iy < tile.NbTiley; iy++)
		for (int ix = 0; ix < tile.NbTilex; ix++)
			for (int iix = 0; iix < XTile; iix++)
				for (int iiy = 0; iiy < YTile; iiy++) {

					int iscratch = lostpixels + iix + dxSCRo2; 		// contribution of x in the 1D SCRATCH
					iscratch += ix * XSCRATCH; 					// contribution of previous tiles in x
					iscratch += (iiy + dySCRo2) * XSCRATCH * tile.NbTilex; 		// contribution of y in 1D SCRATCH
					iscratch += iy * YSCRATCH * XSCRATCH  * tile.NbTilex; 	// contribution of previous tiles in y

					int itile = iix;  // contribution of x in the TILE
					itile += ix  * XTile; // contribution of previous tile in x
					itile += iiy * XTile * tile.NbTilex; // contribution of y in the TILE
					itile += iy  * ATile * tile.NbTilex ; // contribution of previous tiles in y

					int iscratch2Dx = iix + dxSCRo2 + ix * XSCRATCH; 	// contribution of x in the 1D SCRATCH + contribution of previous tiles in x
					int iscratch2Dy = iiy + dySCRo2 + iy * YSCRATCH; 		// contribution of y in 1D SCRATCH +contribution of previous tiles in y
					int iscratch2D = iscratch2Dx + iscratch2Dy * XSCRATCH * tile.NbTilex;
					scratchpad_matrix[iscratch] = tile_rec[itile];
					i_scratchpad[iscratch2D] = 255.0 * tile_rec[itile] / Maxscratch;
					if(!(i_scratchpad[iscratch2D] ==0) && VERBOSE){
					printf("SCRATCHPAD \u24FC itile %d, iscratch %d iscratch2Dx %d, iscratch2Dy %d iscratch2D %d\n",
							itile, iscratch, iscratch2Dx, iscratch2Dy, iscratch2D);
					printf("SCRATCHPAD \u24FC itile %d, i_scratchpad[iscratch2D] %d scratchpad_matrix[iscratch] %f tile_rec[itile] %f\n",
							itile, i_scratchpad[iscratch2D], scratchpad_matrix[iscratch], tile_rec[itile]);
					}
				}

	printf("SCRATCHPAD \u24FC :Image of scratchpad matrix  %s .....\n", scratchpadImagefile);
	printf("SCRATCHPAD \u24FC : Max Scratchpad %f Sum scratchpad %f \n", Maxscratch, Sumscratch);
	printf("SCRATCHPAD \u24FC : size of one SCRATCHPAD 2D %d of full SCRATCHPAD 2D %d\n", XSCRATCH * YSCRATCH,
			XSCRATCH * YSCRATCH * tile.NbTileXY);
	sdkSavePGM(scratchpadImagefile, i_scratchpad, XSCRATCH * tile.NbTilex, YSCRATCH * tile.NbTiley);
	free(i_scratchpad);

}

bool Scratchvalidate_host(void) {
	bool testScratchpad;
	float MaxScratchpad = 0.0f, Sum3Scratchpad = 0.0f, max3Scratchpad = 0.0f;

	// write Scratchpad in memory and validate
	unsigned char *i_Scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH, sizeof(unsigned char)); // on host
	cudaMallocManaged(&val_scratchpad, tile.NbTileXY * ASCRATCH * sizeof(float));
	cudaMallocManaged(&val2_scratchpad, tile.NbTileXY * ASCRATCH * sizeof(float));
	const char * ScratchpadValImagefile = "results/ScratchpadValImagefile.pgm";

	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Scratchpad kernel
	Scratchvalidate_device<<<dimGrid, dimBlock, 0>>>(tile.NbTilex,tile.NbTiley, lostpixels);
	cudaDeviceSynchronize();

	for (int arg = 0; arg < ASCRATCH*tile.NbTileXY; arg++) {
			Sum3Scratchpad += *(val_scratchpad + arg);
			max3Scratchpad  = max(max3Scratchpad, *(val_scratchpad + arg));
		}
	printf("SCRATCHPAD \u24FC Sum3Scratchpad  %f max3Scratchpad %f   ", Sum3Scratchpad, max3Scratchpad);

	// write Scratchpad image validation to disk
	/////////////////////////////////
	MaxScratchpad = 0.0f;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int i = 0; i < ASCRATCH *tile.NbTileXY; i++) {
			MaxScratchpad = max(MaxScratchpad, val_scratchpad[i]); // sanity check, check max
		}
	std::cout << "max device =" << MaxScratchpad << "\n";

	for (int ity = 0; ity < tile.NbTiley; ity ++)
		for (int itx = 0; itx < tile.NbTilex; itx ++){
			int it = itx + ity*tile.NbTilex;
			for(int arg = lostpixels; arg < XSCRATCH*YSCRATCH + lostpixels; arg++){
				int arg1D = arg + it*ASCRATCH;
				int argy = (arg - lostpixels)/ XSCRATCH;
				int argx = (arg - lostpixels)% XSCRATCH;
				int arg2D = argx + itx * XSCRATCH + argy*XSCRATCH* tile.NbTilex+ ity * YSCRATCH * XSCRATCH* tile.NbTilex;
				i_Scratchpad[arg2D] = 255.0 * val_scratchpad[arg1D] / MaxScratchpad;			// Validation image value
			}
		}

	printf("SCRATCHPAD \u24FC Path to Scratchpad validation %s .....\n", ScratchpadValImagefile);
	sdkSavePGM(ScratchpadValImagefile, i_Scratchpad, XSCRATCH*tile.NbTilex, YSCRATCH*tile.NbTiley);

	printf("SCRATCHPAD \u24FC Comparing files ... ");
	testScratchpad = compareData(val_scratchpad, scratchpad_matrix, ASCRATCH *tile.NbTileXY,MAX_EPSILON_ERROR, 0.15f);

	for (int jScratchpad = 0; jScratchpad < ASCRATCH *tile.NbTileXY; jScratchpad++) {
		Sumdel[8] += fabsf(*(val_scratchpad + jScratchpad) - *(scratchpad_matrix + jScratchpad));
	}
	printf("Sumdel[8] %f  ", Sumdel[8]);
	std::cout << "testScratchpad = " << testScratchpad << "\n";
	cudaFree(val_scratchpad);
	return (testScratchpad);
}

