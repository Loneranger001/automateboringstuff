import csv
import os
from openpyxl import load_workbook
from recordObj import recordObj
from configparser import ConfigParser

"""
This class will handle the task of parsing excel file and writing csv file.
"""


class csvFileCreator:
    def __init__(self, excel_path):
        self.excel_path = excel_path

    def parseExcel(self):
        # create workbook object
        wb = load_workbook(self.excel_path)
        for ws in wb:
            

