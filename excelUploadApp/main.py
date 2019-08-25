from csvFileCreator import CsvFileCreator
import logging
from os import path
from datetime import datetime
from configparser import ConfigParser
from excelupload import Ui_MainWindow
from PyQt5.QtWidgets import QApplication, QMainWindow, QFileDialog, QMessageBox
# basis settings for logging
logfile = "excel_parser_{0}".format(datetime.now().strftime('%Y%m%d%H%M%S'))
logging.basicConfig(
    filename=logfile,
    level=logging.DEBUG,
    filemode="w",
    format="%(asctime)s: (%(filename)s): %(levelname)s: "
           "%(funcName)s Line: %(lineno)d - %(message)s",
    datefmt="%m/%d/%Y %I:%M:%S %p"
)


class MainWindow(QMainWindow, Ui_MainWindow):
    def __init__(self, appsettings):
        super(MainWindow, self).__init__()
        self.setupUi(self)
        self.file_name = ""
        self.dir_name = ""
        # set initialization variables.
        self.excel_enabled = appsettings['enableexcel']
        self.csv_enabled = appsettings['enablecsv']
        self.delimiter = appsettings['delimiter']
        self.header = appsettings['columns']
        # set up operations
        self.pushButton_browse.clicked.connect(self.openfile_dialog)
        self.pushButton_close.clicked.connect(self.close_window)
        self.pushButton_ok.clicked.connect(self.process_file)
        # enable disable based on settings
        self.radioButton_excl.setEnabled(self.excel_enabled)
        self.radioButton_csv.setEnabled(self.csv_enabled)

    def openfile_dialog(self):
        try:
            file, _ = QFileDialog.getOpenFileName(self, 'Open', 'C:\'', "Excel(*.xlsx *.xls)")
            if file:
                self.file_name = path.basename(file)
                self.dir_name = path.dirname(file)
                # Enable the Button
                self.pushButton_ok.setEnabled(True)
                # instantiate the excel loader class
                # self.exceloader = BackEndOperation(self.dirpath, self.filename)
        except FileNotFoundError:
            QMessageBox.Critical(self, 'File Not Found', 'Selected File Could Not Be Found!', QMessageBox.Ok,
                                 QMessageBox.Ok)
        except Exception as e:
            QMessageBox.Critical(self, 'Exception!', str(e), QMessageBox.Ok,
                                 QMessageBox.Ok)

    def close_window(self):
        self.close()

    def process_file(self):
        pass


def app_settings(section):
    appsetting = {}
    config = ConfigParser()
    if not path.exists('appSettings.ini'):
        config.read('defaultSetting.ini')
    else:
        config.read('appSettings.ini')
    options = config.options(section)
    for option in options:
        try:
            if option == 'delimiter':
                appsetting[option] = config.get(section, option)
            elif option == 'enableexcel':
                appsetting[option] = config.getboolean(section, option)
            elif option == 'enablecsv':
                appsetting[option] = config.getboolean(section, option)
            elif option == 'columns':
                appsetting[option] = config.get(section, option)
            elif option == -1:
                logging.info('Option %s is not enabled.' % option)
        except Exception:
            logging.critical('Error while reading config', exc_info=True)

    return appsetting


def main():

    # initialize the application
    app_config = app_settings('Coreappsetting')
    app = QApplication(sys.argv)
    app.setApplicationName('Excel Converter/Uploader')
    app.setStyle('Windows')
    window = MainWindow(app_config)
    window.show()
    sys.exit(app.exec_())

    # excel_obj = CsvFileCreator('testfile.xlsx')
    # config_dict = excel_obj.configsectionmap('Coreappsetting')
    # if config_dict:
    #     logging.info('Application settings:')
    #     logging.info('Delimiter: %s, '
    #                  'EnableExcel: %s,'
    #                  'EnableCSV: %s'
    #                  % (config_dict['delimiter'],
    #                     config_dict['enableexcel'],
    #                     config_dict['enablecsv']))
    #     delimiter = config_dict['delimiter']
    #     print(type(delimiter))
    #     enableexcel = config_dict['enableexcel']
    #     enablecsv = config_dict['enablecsv']
    #     header = config_dict['columns']
    # else:
    #     logging.warning('Failed to read configuration, will reset to default values.')
    #     delimiter = ','
    #     enableexcel = True
    #     enablecsv = True
    #     header = None
    #
    # parsed_data = excel_obj.parse_excel()
    # if not excel_obj.write_csv('Extracted.csv', parsed_data, delimiter, header):
    #     print('Failed To Write csv')
    # else:
    #     print('CSV File Generated')


if __name__ == '__main__':
    import sys
    # app = QApplication(sys.argv)
    # app.setApplicationName('Excel Converter/Uploader')
    # app.setStyle('Windows')
    # window = MainWindow()
    # window.show()
    main()
    # sys.exit(app.exec_())
