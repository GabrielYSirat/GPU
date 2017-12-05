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

#include "0_Mainparameters.h"

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
	verbosefile << "MAIN PROGRAM  \u24EA NewLoop start ...\n";
	if (devID < 0) {
		printf("exiting...\n");
		exit(EXIT_FAILURE);
	}

	/********************NVIDIA Card assesment and parameters ************************/
	checkCudaErrors(cudaGetDeviceProperties(&deviceProps, devID)); 	// get device name & properties
	TA.MP = deviceProps.multiProcessorCount;
	TA.sharedmemory = deviceProps.sharedMemPerBlock;
	clockRate = deviceProps.clockRate;
	verbosefile << " INIT PROG \u24EA Number of Multiprocessors (MP) " << TA.MP << " clock rate (KHz) " << clockRate
			<< " SharedMemory " << (float) TA.sharedmemory/1024. << " in KBytes\n\n";

	/***************************** command line management*****************************/
	resourcesdirectory = argv[1]; 	// Directory with all preprocessing files and data
	pPSF = retrieveargv(argv[2]);	// PSF Size, without zoom
	Npixel = retrieveargv(argv[3]);	// Pixel number without zoom
	RDISTRIB = retrieveargv(argv[4]);
	pZOOM = retrieveargv(argv[5]);
	Ndistrib = retrieveargv(argv[6]);
	MIFILE = argv[7];
	// to read the values in the program and to add tests

	verbosefile << "MAIN PROGRAM  \u24EA ARG: EXE arguments number argc: " << argc << endl;
	verbosefile << "MAIN PROGRAM  \u24EA command line parameters: " << "******************************************"
			<< endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[1]: working directory: " << resourcesdirectory << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[2]: pPSF: " << pPSF << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[3]: Npixel: " << Npixel << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[4]: RDISTRIB: " << RDISTRIB << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[5]: pZOOM: " << pZOOM << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[6]: NDISTRIB: " << Ndistrib << endl;
	verbosefile << "MAIN PROGRAM  \u24EA ARG: argv[7]: MI directory: " << resourcesdirectory + MIFILE << endl;
	verbosefile << "MAIN PROGRAM  \u24EA command line parameters: " << "******************************************"
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


	verbosefile << "************** DATA: PARAMETERS OF MEASUREMENT *************************************";
	verbosefile << " INIT PROG \u24EA BASIC  : THreadsRatio "<<  THreadsRatio << " NThreads " << NThreads;
	verbosefile << " Npixel " << Npixel <<" pZOOM " << pZOOM << " pPSF " << pPSF << " RDISTRIB " << RDISTRIB << endl;
	verbosefile << " INIT PROG \u24EA BASIC  : YTile " << YTile << " YSCRATCH " << YSCRATCH << " dySCR " << dySCR << endl;
	verbosefile << "INIT PROG \u24EA PIXEL  : Npixel " << Npixel << " PixZoom " << PixZoom << " PixZoomo2 " << PixZoomo2 << endl;
	verbosefile << "INIT PROG \u24EA PIXEL  : lost lines " << lostlines << " additional lines at the end of microimage\n" << endl;
	verbosefile << "INIT PROG \u24EA pPSF   : pPSF " << pPSF << " PSFZoom " << PSFZoom << " PSFZoomo2 " << PSFZoomo2 << endl;
	verbosefile << " INIT PROG \u24EA DISTRIB: XDistrib " << XDistrib << " YDistrib " << YDistrib <<  "extended "
			 << YDistrib_extended << " Size in KBytes " << ADistrib/1024. <<
			 "ADistrib " << ADistrib << " RDISTRIB " << RDISTRIB << endl;
	verbosefile << " INIT PROG \u24EA SCRATCH X&Y: " << XSCRATCH << " " << YSCRATCH << " dxSCR "
			<< dxSCR << " dySCR " << dySCR << endl;
	verbosefile << " INIT PROG \u24EA SCRATCH: DEL SCRATCH " << lostpixels << " Additional pixels at start and end of SCRATCH\n";
	verbosefile << " INIT PROG \u24EA PARAMS :  Number of threads " << NThreads << " Threads per batch "
			<< THREADSVAL <<" number of batch "  << THreadsRatio << endl;
	verbosefile << "************** DATA: PARAMETERS OF MEASUREMENT *************************************\n\n";

	verbosefile << " INIT PROG \u23f3 Data parameters in device memory ...\n";


	/********************************Reconstruction parameters *************************/
	filenamexml = resourcesdirectory + "reconstruction.xml";
	verbosefile << " INIT PROG \u24EA reconstruction xml: " << filenamexml.c_str() << endl;
	doc.LoadFile(filenamexml.c_str());

	TA.Nb_Rows_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Rows")->GetText());
	TA.Nb_Cols_reconstruction = atoi(doc.FirstChildElement("Image_Contents")
			->FirstChildElement("Nb_Cols")->GetText());
	TA.reconstruction_size = TA.Nb_Cols_reconstruction*TA.Nb_Rows_reconstruction;
	verbosefile << " INIT PROG \u24EA reconstruction from tiles: Cols " << TA.Nb_Cols_reconstruction;
	verbosefile << " size " << TA.Nb_Rows_reconstruction << " size " << TA.reconstruction_size;

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
	verbosefile << " INIT PROG \u24EA PARAMS :  original µimage pixel size" << TA.Pixel_size_nm;
	verbosefile << " nm pixel size reconstruction ",TA.Pixel_size_nm/pZOOM;
	TA.XTileSize = (XTile * TA.Pixel_size_nm)/(1000.*pZOOM); 	// Tile size in nm
	TA.YTileSize = (YTile * TA.Pixel_size_nm)/(1000.*pZOOM);	// Tile size in nm
	verbosefile << " INIT PROG \u24EA TILE   : XTILE " << XTile << " YTILE " << YTile
			<< " size : XTILE: " << TA.XTileSize << " YTILE " << TA.YTileSize;
	verbosefile << " INIT PROG \u24EA RECONSTRUCTION in nm   : X " <<  TA.Nb_Cols_reconstruction*TA.Pixel_size_nm/1000.;
	verbosefile << " Y " << TA.Nb_Rows_reconstruction*TA.Pixel_size_nm/1000. << " µm\n";

	return (dimfit);
}

