/*
 * initparameters.cu
 *
 *  Created on: May 7, 2017
 *      Author: gabriel
 */
/*
 *  Created on: April 18, 2017
 *      Author: gabriel
 */

#include "0_NewLoop.h"

/*******************PARAMETERS**************/
char buff[BUFFSIZE]; // a buffer to temporarily park the data
double Timestep[16];
char chars[] = "[]()", delimeter('=');
__managed__ int pPSF, Npixel, RDISTRIB, pZOOM, Ndistrib;

__managed__ double  Energy_global =0.0f;
__managed__ clock_t timer, time_init, time_start; // in KHz

std::string resourcesdirectory, filename, name, value, MIFILE, PSFFILE, DISTRIBFILE;

__managed__ int XTile, YTile, ATile;
__managed__ int THreadsRatio, NThreads;
__managed__ int XDistrib, YDistrib, YDistrib_extended, lostlines, ADistrib;

cudaDeviceProp deviceProps;

bool initparameters( int argc, char **argv) {
	XMLDocument XMLdoc, ACQXML, doc;
	XMLElement *pRoot, *pParm;
	string sstr, filenamexml;
	bool dimfit = TRUE;

	// acquire information on the CUDA device: name and number of multiprocessors
	devID = gpuDeviceInit(devID);
	std::cout << "MAIN PROGRAM  \u24EA NewLoop start ...\n";
	if (devID < 0) {
		printf("exiting...\n");
		exit(EXIT_FAILURE);
	}

	/********************NVIDIA Card assesment and parameters ************************/
	checkCudaErrors(cudaGetDeviceProperties(&deviceProps, devID)); 	// get device name & properties
	TA.MP = deviceProps.multiProcessorCount;
	TA.sharedmemory = deviceProps.sharedMemPerBlock;
	clockRate = deviceProps.clockRate;
	printf(" INIT PROG \u24EA Number of Multiprocessors (MP) %d, clock rate (KHz) %d SharedMemory %6.3f in KBytes\n\n",
			TA.MP, clockRate, (float) TA.sharedmemory/1024.);

	/***************************** command line management*****************************/
	resourcesdirectory = argv[1]; 	// Directory with all preprocessing files and data
	pPSF = retrieveargv(argv[2]);	// PSF Size, without zoom
	Npixel = retrieveargv(argv[3]);	// Pixel number without zoom
	RDISTRIB = retrieveargv(argv[4]);
	pZOOM = retrieveargv(argv[5]);
	Ndistrib = retrieveargv(argv[6]);
	MIFILE = argv[7];
	// to read the values in the program and to add tests

	std::cout << "MAIN PROGRAM  \u24EA ARG: EXE arguments number argc: " << argc << endl;
	std::cout << "MAIN PROGRAM  \u24EA command line parameters: " << "******************************************"
			<< endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[1]: working directory: " << resourcesdirectory << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[2]: pPSF: " << pPSF << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[3]: Npixel: " << Npixel << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[4]: RDISTRIB: " << RDISTRIB << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[5]: pZOOM: " << pZOOM << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[6]: NDISTRIB: " << Ndistrib << endl;
	std::cout << "MAIN PROGRAM  \u24EA ARG: argv[7]: MI directory: " << resourcesdirectory + MIFILE << endl;
	std::cout << "MAIN PROGRAM  \u24EA command line parameters: " << "******************************************"
			<< endl <<endl;

	/** initialize the general parameters and the offset & scale parameters
	 */
	TA.start();
	OFSCAL.start();

	/** Threads parameters
		 *
		 */
		THreadsRatio = CEILING_POS((1.0*PixZoomSquare)/THREADSVAL);
		NThreads = THreadsRatio * THREADSVAL;

		/** distrib parameters: cover all possible values of the distribution up
		 *  to the corner of the microimage included dummy pixels incremented by the pPSF size -1 to avoid counting twice the pixel
		 */
		XDistrib = (PixZoomo2+PSFZoomo2)*2+1;
		YDistrib = (PixZoomo2+PSFZoomo2)*2+1;
		YDistrib_extended = NThreads/PixZoom+PSFZoom;
		lostlines = NThreads/PixZoom - PixZoom +1;

		float tempe = XDistrib * YDistrib_extended;
		ADistrib = CEILING_POS(tempe/THREADSVAL)*THREADSVAL;


	/** SCRATCH and TILE parameters
	 *
	 */
	XTile = XSCRATCH - dxSCR;	// we do not care on x because the distribution will be zero
								// We add lostpixels  at start and end of the scratchpad
								// for "spillover" of the first and last line
	YTile = YSCRATCH - dySCR - lostlines; 	// in y we need the full size
	if((YTile%2)==0) YTile--;				// We insure that YTile is odd
	ATile = XTile * YTile;										// Total size in pixels


	printf("************** DATA: PARAMETERS OF MEASUREMENT *************************************\n"
			" INIT PROG \u24EA BASIC  : THreadsRatio %d NThreads %d Npixel %d pZOOM %d, pPSF %d RDISTRIB %d\n", THreadsRatio, NThreads, Npixel, pZOOM,
			pPSF, RDISTRIB);
	printf(" INIT PROG \u24EA BASIC  : YTile %d YSCRATCH %d dySCR %d \n",YTile ,YSCRATCH, dySCR);

	printf(" INIT PROG \u24EA PIXEL  : Npixel %d PixZoom %d PixZoomo2 %d\n", Npixel, PixZoom, PixZoomo2);
	printf(" INIT PROG \u24EA PIXEL  : lost lines %d additional lines at the end of microimage\n", lostlines);

	printf(" INIT PROG \u24EA pPSF   : pPSF %d PSFZoom %d PSFZoomo2 %d \n", pPSF, PSFZoom, PSFZoomo2);
	printf(" INIT PROG \u24EA DISTRIB: XDistrib %d YDistrib %d YDistrib_extended %d  Size in KBytes %g ADistrib %d RDISTRIB %d\n",
											XDistrib, YDistrib, YDistrib_extended, ADistrib/1024., ADistrib, RDISTRIB);
	printf(" INIT PROG \u24EA SCRATCH: XSCRATCH %d YSCRATCH %d dxSCR %d dySCR %d\n", XSCRATCH, YSCRATCH, dxSCR, dySCR);
	printf(" INIT PROG \u24EA SCRATCH: DEL SCRATCH %d Additional pixels at start and end of SCRATCH\n", lostpixels);
	printf(" INIT PROG \u24EA PARAMS :  Number of threads %d Threads per batch %d number of batch %d\n",
	NThreads, THREADSVAL, THreadsRatio);
	printf("************** DATA: PARAMETERS OF MEASUREMENT *************************************\n\n");

	printf(" INIT PROG \u23f3 Data parameters in device memory ...\n");


	/********************************Reconstruction parameters *************************/
	filenamexml = resourcesdirectory + "reconstruction.xml";
	printf(" INIT PROG \u24EA reconstruction xml:  %s \n", filenamexml.c_str());
	doc.LoadFile(filenamexml.c_str());

	TA.Nb_Rows_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Rows")->GetText());
	TA.Nb_Cols_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Cols")->GetText());
	TA.reconstruction_size = TA.Nb_Cols_reconstruction*TA.Nb_Rows_reconstruction;
	printf(" INIT PROG \u24EA reconstruction from tiles: Cols %d Rows: %d size %d \n",
				 TA.Nb_Cols_reconstruction, TA.Nb_Rows_reconstruction, TA.reconstruction_size);

	/***********************Sizes in nm *************************************************/
	filename = resourcesdirectory + "ACQ.xml";
	int LoadACQOK = XMLError(ACQXML.LoadFile(filename.c_str()));
	pRoot = ACQXML.FirstChildElement("BioAxialAcquisitionRequest");
	pParm = pRoot->FirstChildElement("Camera_parameters")->FirstChildElement("PixelSize_nm");
	sstr = pParm->GetText();
	for (unsigned int i = 0; i < strlen(chars); ++i)
		sstr.erase(std::remove(sstr.begin(), sstr.end(), chars[i]), sstr.end());
	stringstream stream_p(sstr);
	stream_p.getline(buff, 10, ',');
	TA.Pixel_size_nm = atoi(buff);
	printf(" INIT PROG \u24EA PARAMS :  original µimage pixel size %g  nm pixel size reconstruction %g\n",
			TA.Pixel_size_nm, TA.Pixel_size_nm/pZOOM);
	TA.XTileSize = (XTile * TA.Pixel_size_nm)/(1000.*pZOOM); 	// Tile size in nm
	TA.YTileSize = (YTile * TA.Pixel_size_nm)/(1000.*pZOOM);	// Tile size in nm
	printf(" INIT PROG \u24EA TILE   : XTILE %d YTILE %d  size : XTILE:%6.3f µm YTILE %6.3f µm\n",  XTile, YTile, TA.XTileSize, TA.YTileSize);
	printf(" INIT PROG \u24EA RECONSTRUCTION in nm   : X %6.3f µm Y %6.3f µm\n",
			 TA.Nb_Cols_reconstruction*TA.Pixel_size_nm/1000., TA.Nb_Rows_reconstruction*TA.Pixel_size_nm/1000.);

	return (dimfit);
}

