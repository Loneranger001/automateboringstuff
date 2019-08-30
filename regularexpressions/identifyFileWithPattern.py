import os
import re
import sys
import datetime
import logging

scriptName=os.path.basename(sys.argv[0])
baseName=os.path.splitext(scriptName)[0]
# print(baseName)
tday = datetime.datetime.today().strftime('%y%m%d%H%M%S')
# print(tday)
logFile = '_'.join([baseName.lower(), tday])
# print(logFile)

logging.basicConfig(
    filename=logFile,
    level=logging.DEBUG,
    filemode='w',
    format='%(asctime)s: %(filename)s: %(levelname)s: %(funcName)s: Line %(lineno)d - %(message)s',
    datefmt='%m/%d/%Y %I:%M:%S %p'
)

# print current working directory
print(os.getcwd())
# change working directory
os.chdir('C:\\Users\\asfak\\Desktop')
print(os.getcwd())

filePattern = re.compile(r'''(
(WMAUHLDCHD)     # file prefix
(\.)              # dot 
(I[0-9]+)         # ext
)
''', re.VERBOSE)
# mo = filePattern.findall('WMAUHLDCHD.I000004534 & WMAUHLDCHD.C000004534 & WMAUHLDCHD.I000064533')
# print(mo)
# mo = filePattern.search('FMAUHLDCHD.I000004534')
# print(mo)
# popualte a list with files
# fileList= [file for file in filePattern.findall(f for f in os.listdir())[0]]

#
logging.info('Searching header files with prefix WMAUHLDCHD*.')
fileList = [f for f in os.listdir() if filePattern.search(f)]
logging.info('%d files found for processing.' % len(fileList))
print(fileList)


#
# for record in mo:
#     headerFileName=record[0]
#     print(headerFileName)
#     ext=str(record[3]).replace('I', '').strip('0')




