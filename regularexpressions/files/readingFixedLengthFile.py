import os
import sys
from datetime import datetime


class InvalidDataFormat(Exception):
    pass


class FileHandling:
    def __init__(self, input_file):
        self.input_file = input_file

    def readFile(self):
        lineNum = 1
        if os.path.isfile(self.input_file):
            fileObject = open(self.input_file, 'r')
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
                    if record_type != 'FHEAD':
                        raise InvalidDataFormat('%s Is In Invalid Format' % self.input_file)
                    # print(loc)
                    lineNum += 1
        else:
            raise FileExistsError('%s Could Not Be Found In The Directory %s' % (self.input_file, os.getcwd()))


if __name__ == '__main__':

    input_file = sys.argv[1]
    print(input_file)
    #Instantiate
    fileObj = FileHandling(input_file)
    fileObj.readFile()

