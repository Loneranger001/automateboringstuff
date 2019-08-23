import csv
import os
from openpyxl import load_workbook
from recordObj import recordObj
from configparser import ConfigParser
import logging
from datetime import datetime

"""
This class will handle the task of parsing excel file and writing csv file.
"""

# basis settings for logging
logfile = "excel_parser_{0}".format(datetime.now().strftime('%Y%m%d%H%M%S'))
logging.basicConfig(
    filename="excel_parser.log",
    level=logging.DEBUG,
    filemode="w",
    format="Name: %(user_name)s : %(asctime)s: %(filename)s: %(levelname)s: %(funcName)s Line: %(lineno)d - %(message)s",
    datefmt="%m/%d/%Y %I:%M:%S %p"
)


class CsvFileCreator:
    def __init__(self, excel_path):
        self.excel_path = excel_path
        self.config = ConfigParser()
        self.config.read('appSettings.ini')

    def configsectionmap(self, section):
        dict1 = {}
        options = self.config.options(section)
        for option in options:
            try:
                dict1[option] = self.config.get(section, option)
                if dict1[option] == -1:
                    logging.warning(f'skip option %s' % option)
            except:
                print("exception on %s" % option)
                dict1[option] = None
        return dict1

    def parse_excel(self):
        try:
            # create workbook object
            wb = load_workbook(self.excel_path)
            rangeData = []
            for ws in wb:
                for rows in ws.iter_rows(ws.min_row, ws.max_row, ws.min_column, ws.max_column):
                    rowData = []
                    for row in rows:
                        rowData.append(row.value)
                    # print(rowData)
                    rangeData.append(rowData)
            # print(rangeData)
            return rangeData
        except Exception as ex:
            pass

    def write_csv(self, file_name, input_data):
        try:
            file_path = os.path.dirname(self.excel_path)
            full_path = os.path.join(file_path, file_name)
            print(full_path)
            # open the file for writing
            with open(full_path, newline='', mode='w') as File:
                writer = csv.writer(File)
                writer.writerows(input_data)
            return True
        except Exception as ex:
            print(ex)
            return False









