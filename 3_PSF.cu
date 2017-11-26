/*
 * readvalidatePSF_control.cu
 *
 *  Created on: Apr 19, 2017
 *      Author: gabriel
 */

#include "0_NewLoop.h"
string PSFDATA = "/lambda_488/Calib/system_PSF.bin";
double *double_PSF;			// on host
float MaxPSF=0.0f, SumPSF = 0.0f;

void PSFprepare(void) {
	char * memblock;
	int size;
//	XMLDocument doc;
//	MaxPSF = 0.; // also used as extern

	string PSFraw = resourcesdirectory + PSFDATA;
	const char * PSFImagefile = "results/PSFImagefile.pgm";

	unsigned char *i_PSF = (unsigned char *) calloc(TA.PSF_size, sizeof(unsigned char)); // on host
	double* double_PSF = (double*)std::malloc(TA.PSF_Rows*TA.Nb_Cols_PSF * sizeof(double));
	cudaMallocManaged(&original_PSF, PSFZoom * PSFZoom * sizeof(float));
	cudaMallocManaged(&PSFARRAY, PSFZoom * PSFZoom *  sizeof(float));

	//read pPSF bin file
	std::ifstream PSFile(PSFraw.c_str(), ios::in | ios::binary | ios::ate);
	size = (PSFile.tellg()); 	// the data is stored in doubles of 8 bytes in the file
	size -= byte_skipped;  				// removes byte_skipped
	memblock = new char[size];
	PSFile.seekg(byte_skipped, ios::beg); // 4 first bytes are offset
	PSFile.read(memblock, size);
	PSFile.close();

	double_PSF = (double*) memblock; //reinterpret the chars stored in the file as double
	for (int i = 0; i < TA.PSF_Rows*TA.Nb_Cols_PSF; i++) {
				*(original_PSF + i) = *(double_PSF + i)+0.000001;			// change to float
				SumPSF += *(original_PSF+i);
				if (MaxPSF < *(original_PSF + i))
					MaxPSF = *(original_PSF + i); // sanity check, check max
	}

	verbosefile << " PSF \u24F5  Nb_Rows: " << TA.PSF_Rows << " Nb_Cols " << TA.Nb_Cols_PSF;
	verbosefile << " size " << size << " Max: " << MaxPSF << " Sum " << SumPSF << std::endl;
	std::cout << " PSF \u24F5  Nb_Rows: " << TA.PSF_Rows << " Nb_Cols " << TA.Nb_Cols_PSF;
	std::cout << " size " << size << " Max: " << MaxPSF << " Sum " << SumPSF << std::endl;

	tile.expectedmax = MaxPSF; // to be updated later on

	// write pPSF original image to disk
	/////////////////////////////////
	for (int i = 0; i <= TA.PSF_size; i++)
		i_PSF[i] = 255.0*original_PSF[i]/MaxPSF;			// image value
	verbosefile << " PSF \u24F5 function read: Path to pPSF original" << PSFImagefile << endl;

	sdkSavePGM(PSFImagefile, i_PSF, TA.PSF_Rows, TA.Nb_Cols_PSF);
	free(i_PSF);
 }


bool PSFvalidateonhost(void) {
	bool testPSF;
	double MaxPSF;
	double Sum3PSF = 0, max3PSF =0;
		cudaMallocManaged(&PSF_valid, TA.PSF_size * sizeof(float)); // representation of pPSF available in global memory
	unsigned char *i_PSF = (unsigned char *) calloc(TA.PSF_size, sizeof(unsigned char)); // on host
	const char * PSFValidationimage = "results/PSFValidationimage.pgm";

    dim3 dimBlock(1, 1, 1);
    dim3 dimGrid(1,1, 1);
    // Execute the pPSF kernel
    PSFvalidateondevice<<<dimGrid, dimBlock, 0>>>( TA.PSF_Rows, TA.Nb_Cols_PSF);
    cudaDeviceSynchronize();

   for(int row = 0; row < TA.PSF_Rows; row++)
    	for( int col = 0; col < TA.Nb_Cols_PSF; col++){
    		Sum3PSF += *(PSF_valid + row*TA.Nb_Cols_PSF + col);
     		max3PSF = max(*(PSF_valid + row*TA.Nb_Cols_PSF + col), max3PSF);
    		}
	verbosefile << " PSF \u24F5 Sum3PSF " << Sum3PSF << " max3PSF " << max3PSF << endl;

	// write pPSF image validation to disk
	/////////////////////////////////
	MaxPSF = 0.0f;
	for (int i = 0; i <= TA.PSF_size; i++) {
		MaxPSF = max(MaxPSF, PSF_valid[i]); // sanity check, check max
	}

	for (int i = 0; i <= TA.PSF_size; i++)
		i_PSF[i] = 255.0*PSF_valid[i]/MaxPSF;			// Validation image value

	verbosefile << " PSF \u24F5 Path to pPSF validation ..." << PSFValidationimage << endl;

	    	sdkSavePGM(PSFValidationimage, i_PSF, TA.PSF_Rows, TA.Nb_Cols_PSF);

	    	verbosefile << " PSF \u24F5  Comparing files ... \n";
	    	testPSF = compareData(PSF_valid,
	                                 original_PSF,
	                                 TA.Nb_Cols_PSF*TA.PSF_Rows,
	                                 MAX_EPSILON_ERROR/1000,
	                                 0.15f);

	        for (int jPSF = 0; jPSF < TA.PSF_size; jPSF++)
	        	Sumdel[1] += fabsf(*(PSF_valid+jPSF)- *(original_PSF+jPSF));
cudaFree(PSF_valid);
return(testPSF);
}
