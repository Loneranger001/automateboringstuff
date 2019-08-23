from csvFileCreator import CsvFileCreator

# main function
def main():
    excelObj = CsvFileCreator('testfile.xlsx')
    parsedData = excelObj.parse_excel()
    if not excelObj.write_csv('Extracted.csv', parsedData):
        print('Failed to write csv')
    else:
        print('CSV File Generated')


if __name__ == '__main__':
    main()