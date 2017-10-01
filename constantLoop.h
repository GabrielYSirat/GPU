/*
 * constantLoop.h
 *
 *  Created on: Jul 6, 2017
 *      Author: gabriel
 */

#ifndef CONSTANTLOOP_H_
#define CONSTANTLOOP_H_


/*************General macros and variables ******************************/
#define CEILING_POS(X) ((X-(int)(X)) > 0 ? (int)(X+1) : (int)(X))
#define DIVIDEBY2EVEN(X) ((X-(X/2)*2) > 0 ? (int)(X) : (X+1))

////////////////////////////////////////////////////////////////////////////////
// Constants
#define MAX_EPSILON_ERROR 5e-3f
#define TRUE 1
#define FALSE 0
#define X 0
#define Y 1
#define verbose 0
#define BUFFSIZE 80

// Maximum for values which cannot be determined at compile time
#define NUMLASERPOSITIONS 250000
#define MAXTILE 4096
#define MAXNBDISTRIB 8
#define MAXNUMBERLASERTILE 256
#define MAXTHRRATIO 4
#define MAXNPIXEL 24
#define MAXNPIXELZOOM 48

// Fixed values
#define BANKNUMBER 32
#define NIMAGESPARALLEL 16
#define THREADSVAL 320
#define NSCRATCH 25  // shared memory size is NSCRATCH multiplied by THREADSVAL * sizeof(float) in Kbytes
#define NumBankScratch 1

/** Shortcut parameters
 *
 */
#define PixZoom (Npixel*pZOOM)// verifier
#define PixZoomSquare (Npixel*Npixel)
#define PixSquare (Npixel*Npixel)
#define PixZoomo2 (PixZoom/2)// verifier
#define PSFZoom (pPSF*pZOOM)
#define PSFZoomo2 (PSFZoom/2)
#define PSFZOOMSQUARE (PSFZoom*PSFZoom) // PSFZoom square
#define RdistribZoom (RDISTRIB * pZOOM)

/** Tile to SCRATCH parameters
 *
 */

#define dxSCR (RdistribZoom-1)
#define dxSCRo2 (dxSCR/2)
#define dySCR (2*(PSFZoomo2+PixZoomo2))
#define dySCRo2 (dySCR/2)

#define lostpixels (dySCRo2 -dxSCRo2)

/** Scratchpad parameters
 *
 */
#define	XSCRATCH (PixZoom + NumBankScratch * BANKNUMBER )  // to be updated
#define ASCRATCH (NSCRATCH*THREADSVAL)
#define BSCRATCH  (ASCRATCH - 2*lostpixels)
#define	YSCRATCH (BSCRATCH / XSCRATCH)

#endif /* CONSTANTLOOP_H_ */
