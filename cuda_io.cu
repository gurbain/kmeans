/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
/*   File:         file_io.c                                                 */
/*   Description:  This program reads point data from a file                 */
/*                 and write cluster output to files                         */
/*   Input file format:                                                      */
/*                 ascii  file: each line contains 1 data object             */
/*                 binary file: first 4-byte integer is the number of data   */
/*                 objects and 2nd integer is the no. of features (or        */
/*                 coordinates) of each object                               */
/*                                                                           */
/*   Author:  Wei-keng Liao                                                  */
/*            ECE Department Northwestern University                         */
/*            email: wkliao@ece.northwestern.edu                             */
/*   Copyright, 2005, Wei-keng Liao                                          */
/*                                                                           */
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>     /* strtok() */
#include <sys/types.h>  /* open() */
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>     /* read(), close() */

#include "kmeans.h"

#define MAX_CHAR_PER_LINE 128

int infile_b;
FILE *infile_t;
int   lineLen;


/*---< file_read_head() >---------------------------------------------------------*/
int file_read_head(int   isBinaryFile,  /* flag: 0 or 1 */
                  char *filename,      /* input file name */
                  int  *numObjs,       /* no. data objects (local) */
                  int  *numCoords)     /* no. coordinates */
{
	int     len;
	ssize_t numBytesRead;

	if (isBinaryFile) {  /* input file is in raw binary format -------------*/
		if ((infile_b = open(filename, O_RDONLY, "0600")) == -1) {
			fprintf(stderr, "[file io] error: no such file (%s)\n", filename);
			return 0;
		}
		numBytesRead = read(infile_b, numObjs,    sizeof(int));
		assert(numBytesRead == sizeof(int));
		numBytesRead = read(infile_b, numCoords, sizeof(int));
		assert(numBytesRead == sizeof(int));
		if (_debug) {
			printf("[file io] file %s numObjs   = %d\n",filename,*numObjs);
			printf("[file io] file %s numCoords = %d\n",filename,*numCoords);
		}
        
	} else {  /* input file is in ASCII format -------------------------------*/
		char *line, *ret;

		if ((infile_t = fopen(filename, "r")) == NULL) {
			fprintf(stderr, "[file io] error: no such file (%s)\n", filename);
			return 0;
		}

		/* first find the number of objects */
		lineLen = MAX_CHAR_PER_LINE;
		line = (char*) malloc(lineLen);
		assert(line != NULL);

		(*numObjs) = 0;

		while (fgets(line, lineLen, infile_t) != NULL) {
			/* check each line to find the max line length */
			while (strlen(line) == lineLen-1) {
				/* this line read is not complete */
				len = strlen(line);
				fseek(infile_t, -len, SEEK_CUR);

				/* increase lineLen */
				lineLen += MAX_CHAR_PER_LINE;
				line = (char*) realloc(line, lineLen);
				assert(line != NULL);

				ret = fgets(line, lineLen, infile_t);
				assert(ret != NULL);
			}

			if (strtok(line, " \t\n") != 0)
				(*numObjs)++;
		}
		rewind(infile_t);
		if (_debug) printf("[file io] lineLen = %d\n",lineLen);

		/* find the no. objects of each object */
		(*numCoords) = 0;
		while (fgets(line, lineLen, infile_t) != NULL) {
			if (strtok(line, " \t\n") != 0) {
				/* ignore the id (first coordiinate): numCoords = 1; */
				while (strtok(NULL, " ,\t\n") != NULL) (*numCoords)++;
				break; /* this makes read from 1st object */
			}
		}
		rewind(infile_t);
		if (_debug) {
			printf("[file io] file %s numObjs   = %d\n",filename,*numObjs);
			printf("[file io] file %s numCoords = %d\n",filename,*numCoords);
		}
    }    
	return 1;
}

/*---< file_read_head() >---------------------------------------------------------*/
float** file_read_block(int   isBinaryFile,  /* flag: 0 or 1 */
                  char *filename,      /* input file name */
                  int  numObjs,       /* no. data objects (local) */
                  int  numCoords)     /* no. coordinates */
{
	int     i, j;
	ssize_t numBytesRead;
	float **objects;
    
	int len = numObjs * numCoords;
	
	if (_debug)
		printf("[file io] read a block of %ix%i objects\n", numObjs, numCoords);
	if (isBinaryFile) {  /* input file is in raw binary format -------------*/
		
		objects    = (float**)malloc(numObjs * sizeof(float*));
		assert(objects != NULL);
		objects[0] = (float*) malloc(len * sizeof(float));
        assert(objects[0] != NULL);
        for (i=1; i<numObjs; i++)
            objects[i] = objects[i-1] + numCoords;

		numBytesRead = read(infile_b, objects[0], len*sizeof(float));
		assert(numBytesRead == len*sizeof(float));

	} else {  /* input file is in ASCII format -------------------------------*/

		char *line = (char*) malloc(lineLen);
		int llen;
        objects    = (float**)malloc(numObjs * sizeof(float*));
        assert(objects != NULL);
        objects[0] = (float*) malloc(len * sizeof(float));
        assert(objects[0] != NULL);
        for (i=1; i<numObjs; i++)
            objects[i] = objects[i-1] + numCoords;

        i = 0;
        /* read all objects */
        while (fgets(line, lineLen, infile_t) != NULL && i < numObjs) {
			if (i == 0)
				llen = strlen(line);
            if (strtok(line, " \t\n") == NULL)
				continue;
            for (j=0; j<numCoords; j++)
                objects[i][j] = atof(strtok(NULL, " ,\t\n"));
            i++;
        }
		fseek(infile_t, -llen, SEEK_CUR);
        free(line);
    }
    //if(_debug)
		//printf("[file io] first data values: %.4f %.4f %.4f %.4f\n", objects[0][0], objects[0][1], objects[1][0], objects[1][1]);
	
    return objects;
}

       
int file_read_close(int isBinaryFile)
{
	if (isBinaryFile)
		close(infile_b);
	else
		fclose(infile_t);
	
	return 1;
}

/*---< file_write() >---------------------------------------------------------*/
int file_write(char      *filename,     /* input file name */
               int        numClusters,  /* no. clusters */
               int        numObjs,      /* no. data objects */
               int        numCoords,    /* no. coordinates (local) */
               float    **clusters,     /* [numClusters][numCoords] centers */
               int       *membership)   /* [numObjs] */
{
    FILE *fptr;
    int   i, j;
    char  outFileName[1024];

    /* output: the coordinates of the cluster centres ----------------------*/
    sprintf(outFileName, "%s.cluster_centres", filename);
    printf("\n[file io] writing coordinates of K=%d cluster centers to file \"%s\"\n",
           numClusters, outFileName);
    fptr = fopen(outFileName, "w");
    for (i=0; i<numClusters; i++) {
        fprintf(fptr, "%d ", i);
        for (j=0; j<numCoords; j++)
            fprintf(fptr, "%f ", clusters[i][j]);
        fprintf(fptr, "\n");
    }
    fclose(fptr);

    /* output: the closest cluster centre to each of the data points --------*/
    sprintf(outFileName, "%s.membership", filename);
    printf("[file io] writing membership of N=%d data objects to file \"%s\"\n",
           numObjs, outFileName);
    fptr = fopen(outFileName, "w");
    for (i=0; i<numObjs; i++)
        fprintf(fptr, "%d %d\n", i, membership[i]);
    fclose(fptr);

    return 1;
}
