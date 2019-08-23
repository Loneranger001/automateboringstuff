from openpyxl import load_workbook
import os
from datetime import datetime
import configparser


def main():
    print(os.getcwd())
    wb = load_workbook('testfile.xlsx')
    print(type(wb))
    print(wb.get_sheet_names())
    print(wb.sheetnames)
    # change sheet name, loop through all worksheet inside workbook
    # for ws in wb:
    ws = wb.get_sheet_by_name('SS')  # takes a sheet name and returns a sheet object
    print(type(ws))
    print(ws.title)
    print(wb.active)
    print(type(ws['A2'].value))
    print(type(ws.cell(2,4).value))
    print(datetime.strftime(ws['A2'].value, '%Y-%m-%d %H:%M:%S'))



if __name__ == '__main__':
    main()
