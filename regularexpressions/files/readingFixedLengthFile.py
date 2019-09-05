import os
import sys
from datetime import datetime

def readFile(file):
    lineNum = 1
    if os.path.isfile(file):
        fileObject = open(file, 'r')
        # read line by line, reads all line together.
        readLines = fileObject.readlines()
        for line in readLines:
            if lineNum == 1:
                print(line)
                record_type = line[0:5]
                line_number = int(line[6:15])
                item_type = line[15:19]
                stake_date = datetime.strptime(line[33:41], '%Y%m%d')
                cycle_count = int(line[43:55])
                loc_type = line[55:56]
                loc = int(line[56:67])
                print(record_type)
                print(line_number)
                print(item_type)
                print(stake_date)
                print(cycle_count)
                print(loc_type)
                print(loc)
                # print(loc)
                lineNum += 1


    else:
        raise FileExistsError('%s Could Not Be Found In The Directory %s' % (file, os.getcwd()))


if __name__ == '__main__':
    readFile('I-stkupld_5832_20190709.dat.bak2')
