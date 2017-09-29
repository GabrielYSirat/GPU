/*
 * readvalidatePSF_control.cu
 *
 *  Created on: Apr 19, 2017
 *      Author: gabriel
 */

#include "NewLoop.h"
double *double_PSF;
float  *original_PSF=NULL;
float MaxPSF=0.0f, SumPSF = 0.0f;

void PSFprepare(void) {
	char * memblock;
	int size;
	XMLDocument doc;
	MaxPSF = 0.; // also used as extern

	string PSFraw = resourcesdirectory + "psf__27x27.raw";
	const char * PSFImagefile = "results/PSFImagefile.pgm";

	filename = resourcesdirectory + "bead_system_PSF.xml";
	printf(" PSF \u24F5 bead_system_PSF:  %s \n", filename.c_str());
	doc.LoadFile(filename.c_str());
	int Nb_Rows_PSF_file = atoi(doc.FirstChildElement("Image_Contents")->FirstChildElement("Nb_Rows")->GetText());
	int Nb_Cols_PSF_file = atoi(doc.FirstChildElement("Image_Contents")->FirstChildElement("Nb_Cols")->GetText());
	if ((Nb_Rows_PSF_file != TA.PSF_Rows)||(Nb_Cols_PSF_file != TA.Nb_Cols_PSF))
		printf(" PSF \u24F5 values stored in xml file differs from parameters File x: %d y: %d parameters x: %d y: %d \n",
				Nb_Rows_PSF_file, Nb_Cols_PSF_file, TA.PSF_Rows, TA.Nb_Cols_PSF);

	unsigned char *i_PSF = (unsigned char *) calloc(TA.PSF_size, sizeof(unsigned char)); // on host
    double* double_PSF = (double*)std::malloc(Nb_Rows_PSF_file*Nb_Cols_PSF_file * sizeof(double));
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
	for (int i = 0; i < Nb_Rows_PSF_file*Nb_Cols_PSF_file; i++) {
				*(original_PSF + i) = *(double_PSF + i)+0.000001;			// change to float
				SumPSF += *(original_PSF+i);
				if (MaxPSF < *(original_PSF + i))
					MaxPSF = *(original_PSF + i); // sanity check, check max
	}

	printf(" PSF \u24F5  Nb_Rows: %d Nb_Cols_PSF %d size pPSF = %d max %g Sum %g \n",
			TA.PSF_Rows, TA.Nb_Cols_PSF, size, MaxPSF,SumPSF );
	tile.expectedmax = MaxPSF; // to be updated later on

	//    cudaMemcpyToSymbol(PSFARRAY, original_PSF, PSFZOOMSQUARE*sizeof(float));


	// write pPSF original image to disk
	/////////////////////////////////
	for (int i = 0; i <= TA.PSF_size; i++)
		i_PSF[i] = 255.0*original_PSF[i]/MaxPSF;			// image value
	printf(" PSF \u24F5 function read: Path to pPSF original %s .....\n", PSFImagefile);

	sdkSavePGM(PSFImagefile, i_PSF, TA.PSF_Rows, TA.Nb_Cols_PSF);
	free(i_PSF);

 }


bool PSFvalidateonhost(void) {
	bool testPSF;
	double MaxPSF;
	double Sum3PSF = 0, max3PSF =0;
		cudaMallocManaged(&PSFvalidationdata_managed, TA.PSF_size * sizeof(float)); // representation of pPSF available in global memory
	unsigned char *i_PSF = (unsigned char *) calloc(TA.PSF_size, sizeof(unsigned char)); // on host
	const char * PSFValidationimage = "results/PSFValidationimage.pgm";

    dim3 dimBlock(1, 1, 1);
    dim3 dimGrid(1,1, 1);
    // Execute the pPSF kernel
    PSFvalidateondevice<<<dimGrid, dimBlock, 0>>>( TA.PSF_Rows, TA.Nb_Cols_PSF);
    cudaDeviceSynchronize();

   for(int row = 0; row < TA.PSF_Rows; row++)
    	for( int col = 0; col < TA.Nb_Cols_PSF; col++)
    		{
    		Sum3PSF += *(PSFvalidationdata_managed + row*TA.Nb_Cols_PSF + col);
     		if (max3PSF < *(PSFvalidationdata_managed + row*TA.Nb_Cols_PSF + col)) max3PSF = *(PSFvalidationdata_managed + row*TA.Nb_Cols_PSF + col);
    		}
	printf(" PSF \u24F5 Sum3PSF  %f max3PSF %f ", Sum3PSF, max3PSF);

	// write pPSF image validation to disk
	/////////////////////////////////
	MaxPSF = 0.0f;
	for (int i = 0; i <= TA.PSF_size; i++) {
		MaxPSF = max(MaxPSF, PSFvalidationdata_managed[i]); // sanity check, check max
	}
	cout << "max device = (3 digits) " << MaxPSF << "\n";
	for (int i = 0; i <= TA.PSF_size; i++)
		i_PSF[i] = 255.0*PSFvalidationdata_managed[i]/MaxPSF;			// Validation image value

	printf(" PSF \u24F5 Path to pPSF validation %s .....\n", PSFValidationimage);

	    	sdkSavePGM(PSFValidationimage, i_PSF, TA.PSF_Rows, TA.Nb_Cols_PSF);

	        printf(" PSF \u24F5 Comparing files ... \n");
	    	testPSF = compareData(PSFvalidationdata_managed,
	                                 original_PSF,
	                                 TA.Nb_Cols_PSF*TA.PSF_Rows,
	                                 MAX_EPSILON_ERROR/1000,
	                                 0.15f);

	        for (int jPSF = 0; jPSF < TA.PSF_size; jPSF++)
	        	Sumdel[1] += fabsf(*(PSFvalidationdata_managed+jPSF)- *(original_PSF+jPSF));
cudaFree(PSFvalidationdata_managed);
return(testPSF);
}
