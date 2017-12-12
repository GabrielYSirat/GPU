/*
 * RSVReconstruction.cu
 *
 *  Created on: Jul 8, 2017
 *      Author: gabriel
 */
#include "0_Mainparameters.h"
std::string filenameimage;
std::string RECFILE = "image_iteration_0__63x114_4em";
std::string endREC = ".raw";
const char * reconstructionImagefile = "results/D_reconstruction.pgm";
const char * recValImagefile = "results/D_reconstructiondevice.pgm";
const char * rectilereconstructionfile = "results/D_reconstructionreorganized.pgm";
const char * scratchpadImagefile = "results/E_scratchpad.pgm";
const char * ScratchpadValImagefile = "results/E_Scratchpaddevice.pgm";
float MaxRec = 0.0f, SumRec = 0.0f;
__managed__ float Maxscratch = 0.0f, Sumscratch = 0.0f, maxTile = 0.0f, SumTile = 0.0f;
double *double_rec;
// double* double_rec;

void Recprepare(void) {
	cudaMallocManaged(&original_rec, TA.reconstruction_size * sizeof(float)); // on device with a shadow on host
	cudaMallocManaged(&double_rec, TA.reconstruction_size * sizeof(double)); // on device with a shadow on host
//	double* double_rec = (double*) std::malloc(TA.reconstruction_size * sizeof(double)); // on host

	char * memblock;
	int size;

	filenameimage = resourcesdirectory + RECFILE + endREC;
	verbosefile << "REC \u24FC reconstruction image:  " << filenameimage.c_str() << " \n";
	/** *****************************data arrays allocation*********************************/
	/** original_reconstruction data in float stored on device with a shadow copy on host
	 *  double_rec data in double read from the file
	 *  i_reconstruction normalized data in char on host for image display
	 */

	//read reconstruction raw file
	std::ifstream RecFile(filenameimage.c_str(), ios::in | ios::binary | ios::ate);
	size = (RecFile.tellg()); 	// the data is stored in float of 4 bytes in the file
	size -= byte_skipped; 	// WE REMOVE byte_skipped BYTES
	verbosefile << "REC \u24FC ************file read: size reconstruction in bytes = " << size << endl;
	memblock = new char[size];
	RecFile.seekg(byte_skipped, ios::beg); // byte_skipped first bytes are skipped
	RecFile.read(memblock, size);
	RecFile.close();
	verbosefile << "REC \u24FC *******complete size  " << TA.reconstruction_size << "  Size in Bytes "
			<< TA.reconstruction_size * sizeof(double) << endl;

	/** read reconstruction data from file in double, transfer to float on the global memory of the device and create a normalized image
	 *
	 */
	double_rec = (double*) memblock; //reinterpret the chars stored in the file as float
	for (int i = 0; i < TA.reconstruction_size; i++) {
		*(original_rec + i) = *(double_rec + i);
		SumRec += *(original_rec + i);
		MaxRec = max(*(original_rec + i), MaxRec);
	}	// sanity check, check max and sum

	verbosefile << "REC \u24FC ***  max =" << MaxRec << "  Sum =" << SumRec << endl;
	unsigned char *i_reconstruction = (unsigned char *) calloc(TA.reconstruction_size, sizeof(unsigned char)); // on host
	// write reconstruction image to disk /////////////////////////////////
	for (int i = 0; i < TA.reconstruction_size; i++)
		i_reconstruction[i] = 255.0 * original_rec[i] / MaxRec;			// image value

	verbosefile << "REC \u24FC Path to reconstruction original " << reconstructionImagefile << " .....\n";
	sdkSavePGM(reconstructionImagefile, i_reconstruction, TA.Nb_Cols_reconstruction,
			TA.Nb_Rows_reconstruction);
	free(i_reconstruction);
//	free(double_rec);
}

bool Recvalidate_host(void) {
	bool testrec;
	float MaXTile = 0.0f, Sum3rec = 0.0f, max3rec = 0.0f;

	// write rec in memory and validate
	unsigned char *i_rec = (unsigned char *) calloc(TA.reconstruction_size, sizeof(unsigned char)); // on host
	cudaMallocManaged(&val_rec, TA.reconstruction_size * sizeof(float));

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
	verbosefile << endl << "on host: Sum3rec  " << Sum3rec << " max3rec %f   " << max3rec << endl;

	// write rec image validation to disk
	/////////////////////////////////
	MaXTile = 0.0f;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int i = 0; i < TA.reconstruction_size; i++) {
			MaXTile = max(MaXTile, val_rec[i]); // sanity check, check max
		}
	verbosefile << "max device =" << MaXTile << "\n";
	for (int i = 0; i < TA.reconstruction_size; i++) {
		i_rec[i] = 255.0 * val_rec[i] / MaXTile;			// Validation image value
		if (VERBOSE)
			if (i_rec[i] > 1)
				printf(
						"REC VALIDATION \u24FC position %d, size, %d column width %d xy position (x*y) (%d*%d) "
						"value %g normalized %d\n",
						i, TA.reconstruction_size, TA.Nb_Cols_reconstruction, i % TA.Nb_Cols_reconstruction,
						i / TA.Nb_Cols_reconstruction, val_rec[i], i_rec[i]);
	}
	verbosefile << "REC \u24FC Path to rec validation " << recValImagefile << endl;
	if (VERBOSE)
		printf("---------------------------------------\n");
	sdkSavePGM(recValImagefile, i_rec, TA.Nb_Cols_reconstruction, TA.Nb_Rows_reconstruction);

	verbosefile << "REC \u24FC Comparing files ... ";
	testrec = compareData(val_rec, original_rec, TA.reconstruction_size, MAX_EPSILON_ERROR, 0.15f);

	for (int jrec = 0; jrec < TA.reconstruction_size; jrec++) {
		Sumdel[1] += fabsf(*(val_rec + jrec) - *(original_rec + jrec));
	}
	verbosefile << "Sumdel[1] " << Sumdel[1] << " ... " << endl;
	verbosefile << "testrec = " << testrec << "\n";

	cudaFree(val_rec);
	return (testrec);
}

void Scratchprepare(void) {
	float *tile_rec = (float*) std::calloc(ATile * tile.NbTileXY, sizeof(float)); 					// on host
	unsigned char *i_tilerec = (unsigned char *) calloc(ATile * tile.NbTileXY, sizeof(unsigned char)); // on host
	cudaMallocManaged(&scratchpad_matrix, tile.NbTileXY * ASCRATCH * sizeof(float));
	unsigned char *i_scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH,
			sizeof(unsigned char)); // on host

	/***********************************TILE RECONSTRUCTION ************************/
	verbosefile << "TILE \u24FC Path to tile reconstruction  " << rectilereconstructionfile << endl;

	int deltilex = tile.NbTilex * XTile - TA.Nb_Cols_reconstruction;
	int deltiley = tile.NbTiley * YTile - TA.Nb_Rows_reconstruction;
	verbosefile << " offset = - del /2 !! x " << deltilex / 2 << "  y  " << deltiley / 2 << endl;

	for (int arg = 0; arg < TA.reconstruction_size; arg++) {
		maxTile = max(maxTile, *(original_rec + arg));
		SumTile += *(original_rec + arg);
	}
	Maxscratch = maxTile;
	Sumscratch = SumTile;
	verbosefile << "TILE \u24FC maxTile " << maxTile << " SumTile " << SumTile << endl;

	for (int row = 0; row < TA.Nb_Rows_reconstruction; row++)
		for (int col = 0; col < TA.Nb_Cols_reconstruction; col++) {
			int itemp = col + deltilex / 2 + (row + deltiley / 2) * tile.NbTilex * XTile;
			int itemp2 = col + row * TA.Nb_Cols_reconstruction;
			*(tile_rec + itemp) = *(original_rec + itemp2);
			i_tilerec[itemp] = 255. * *(tile_rec + itemp) / maxTile;
			if (VERBOSE)
				if (i_tilerec[itemp] > 1)
					if (VERBOSE)
						printf(
								"SCRATCHPAD VALIDATION \u24FC position %d, size, %d column width %d xy position (x*y) (%d*%d) "
								"value %g normalized %d\n",
								itemp, TA.reconstruction_size, TA.Nb_Cols_reconstruction, itemp % TA.Nb_Cols_reconstruction,
								itemp / TA.Nb_Cols_reconstruction, tile_rec[itemp], i_tilerec[itemp]);
		}

	if (VERBOSE)
		printf("---------------------------------------\n");
	sdkSavePGM(rectilereconstructionfile, i_tilerec, XTile * tile.NbTilex, YTile * tile.NbTiley);

	verbosefile << "SCRATCHPAD \u24FC Image of scratchpad matrix " << scratchpadImagefile << " .....\n";
	verbosefile << "SCRATCHPAD \u24FC : Max Scratchpad " << Maxscratch << " Sum scratchpad " << Sumscratch
			<< endl;
	verbosefile << "SCRATCHPAD \u24FC : " << XSCRATCH * YSCRATCH << " of full SCRATCHPAD 2D "
			<< XSCRATCH * YSCRATCH * tile.NbTileXY << endl;
	// write scratchpad matrix to disk
	scratchreaddisplay(tile_rec, scratchpad_matrix, scratchpadImagefile, TRUE);

	free(i_scratchpad);

}

bool Scratchvalidate_host(void) {
	bool testScratchpad;
	float Sum3Scratchpad = 0.0f, max3Scratchpad = 0.0f;
	float * dummy = { 0 };

	// write Scratchpad in memory and validate
	unsigned char *i_scratchpad = (unsigned char *) calloc(tile.NbTileXY * XSCRATCH * YSCRATCH,
			sizeof(unsigned char)); // on host
	cudaMallocManaged(&val_scratchpad, tile.NbTileXY * ASCRATCH * sizeof(float));
	cudaMallocManaged(&val2_scratchpad, tile.NbTileXY * ASCRATCH * Ndistrib * sizeof(float));

	dim3 dimBlock(1, 1, 1);
	dim3 dimGrid(1, 1, 1);
	// Execute the Scratchpad kernel
	Scratchvalidate_device<<<dimGrid, dimBlock, 0>>>(tile.NbTilex,tile.NbTiley, lostpixels);
	cudaDeviceSynchronize();

	for (int arg = 0; arg < ASCRATCH * tile.NbTileXY; arg++) {
		Sum3Scratchpad += *(val_scratchpad + arg);
		max3Scratchpad = max(max3Scratchpad, *(val_scratchpad + arg));
	}
	printf("SCRATCHPAD \u24FC Sum3Scratchpad  %f max3Scratchpad %f   \n", Sum3Scratchpad, max3Scratchpad);

	// write Scratchpad image validation to disk
	/////////////////////////////////
	Maxscratch = 0.0f;

	for (int idistrib = 0; idistrib < Ndistrib; idistrib++)
		for (int i = 0; i < ASCRATCH * tile.NbTileXY; i++) {
			if (val_scratchpad[i] > 1. && VERBOSE)
				printf("SCRATCHPAD \u24FC i %d x position in scratch %d y position %d val %f\n", i,
						i % XSCRATCH, i / XSCRATCH, val_scratchpad[i]);
			Maxscratch = max(Maxscratch, val_scratchpad[i]); // sanity check, check max
		}
	verbosefile << "max device =" << Maxscratch << "\n";

	scratchreaddisplay(dummy, val_scratchpad, ScratchpadValImagefile, FALSE);
	verbosefile << "SCRATCHPAD \u24FC Path to Scratchpad validation " << ScratchpadValImagefile << " .....\n";
	verbosefile << "SCRATCHPAD \u24FC Comparing files ... " << endl;
	testScratchpad = compareData(val_scratchpad, scratchpad_matrix, ASCRATCH * tile.NbTileXY,
	MAX_EPSILON_ERROR, 0.15f);

	for (int jScratchpad = 0; jScratchpad < ASCRATCH * tile.NbTileXY; jScratchpad++) {
		Sumdel[8] += fabsf(*(val_scratchpad + jScratchpad) - *(scratchpad_matrix + jScratchpad));
	}
	verbosefile << "Sumdel[8] " << Sumdel[8] << endl;
	verbosefile << "testScratchpad = " << testScratchpad << "\n";
	cudaFree(val_scratchpad);
	return (testScratchpad);
}

