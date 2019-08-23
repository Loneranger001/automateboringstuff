from csvFileCreator import CsvFileCreator

# main function


def main():
    excel_obj = CsvFileCreator('testfile.xlsx')
    config_dict = excel_obj.configsectionmap('Coreappsetting')
    if config_dict:
        print("Delimeter: %s" % config_dict['delimeter'])
        print("Columns: %s" % config_dict['columns'])
        print(config_dict['columns'].split(','))
        # print(config_dict)
    parsed_data = excel_obj.parse_excel()
    if not excel_obj.write_csv('Extracted.csv', parsed_data):
        print('Failed to write csv')
    else:
        print('CSV File Generated')


if __name__ == '__main__':
    main()