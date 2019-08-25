# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'excelupload.ui'
#
# Created by: PyQt5 UI code generator 5.13.0
#
# WARNING! All changes made in this file will be lost!


from PyQt5 import QtCore, QtGui, QtWidgets


class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.resize(488, 435)
        self.centralwidget = QtWidgets.QWidget(MainWindow)
        self.centralwidget.setObjectName("centralwidget")
        self.label_header = QtWidgets.QLabel(self.centralwidget)
        self.label_header.setGeometry(QtCore.QRect(130, 20, 201, 31))
        font = QtGui.QFont()
        font.setFamily("Calibri")
        font.setPointSize(13)
        font.setBold(True)
        font.setWeight(75)
        font.setStyleStrategy(QtGui.QFont.PreferAntialias)
        self.label_header.setFont(font)
        self.label_header.setStyleSheet("color: rgb(0, 0, 255);")
        self.label_header.setAlignment(QtCore.Qt.AlignCenter)
        self.label_header.setObjectName("label_header")
        self.layoutWidget = QtWidgets.QWidget(self.centralwidget)
        self.layoutWidget.setGeometry(QtCore.QRect(280, 330, 195, 30))
        self.layoutWidget.setObjectName("layoutWidget")
        self.horizontalLayout = QtWidgets.QHBoxLayout(self.layoutWidget)
        self.horizontalLayout.setContentsMargins(0, 0, 0, 0)
        self.horizontalLayout.setObjectName("horizontalLayout")
        self.pushButton_ok = QtWidgets.QPushButton(self.layoutWidget)
        self.pushButton_ok.setEnabled(False)
        self.pushButton_ok.setObjectName("pushButton_ok")
        self.horizontalLayout.addWidget(self.pushButton_ok)
        self.pushButton_close = QtWidgets.QPushButton(self.layoutWidget)
        self.pushButton_close.setObjectName("pushButton_close")
        self.horizontalLayout.addWidget(self.pushButton_close)
        self.layoutWidget1 = QtWidgets.QWidget(self.centralwidget)
        self.layoutWidget1.setGeometry(QtCore.QRect(20, 120, 451, 30))
        self.layoutWidget1.setObjectName("layoutWidget1")
        self.horizontalLayout_2 = QtWidgets.QHBoxLayout(self.layoutWidget1)
        self.horizontalLayout_2.setContentsMargins(0, 0, 0, 0)
        self.horizontalLayout_2.setObjectName("horizontalLayout_2")
        self.radioButton_csv = QtWidgets.QRadioButton(self.layoutWidget1)
        self.radioButton_csv.setEnabled(False)
        self.radioButton_csv.setObjectName("radioButton_csv")
        self.buttonGroup_type = QtWidgets.QButtonGroup(MainWindow)
        self.buttonGroup_type.setObjectName("buttonGroup_type")
        self.buttonGroup_type.addButton(self.radioButton_csv)
        self.horizontalLayout_2.addWidget(self.radioButton_csv)
        self.radioButton_excl = QtWidgets.QRadioButton(self.layoutWidget1)
        self.radioButton_excl.setEnabled(False)
        self.radioButton_excl.setObjectName("radioButton_excl")
        self.buttonGroup_type.addButton(self.radioButton_excl)
        self.horizontalLayout_2.addWidget(self.radioButton_excl)
        self.pushButton_browse = QtWidgets.QPushButton(self.layoutWidget1)
        self.pushButton_browse.setObjectName("pushButton_browse")
        self.horizontalLayout_2.addWidget(self.pushButton_browse)
        MainWindow.setCentralWidget(self.centralwidget)
        self.menubar = QtWidgets.QMenuBar(MainWindow)
        self.menubar.setGeometry(QtCore.QRect(0, 0, 488, 26))
        self.menubar.setObjectName("menubar")
        self.menuAction = QtWidgets.QMenu(self.menubar)
        self.menuAction.setObjectName("menuAction")
        MainWindow.setMenuBar(self.menubar)
        self.statusbar = QtWidgets.QStatusBar(MainWindow)
        self.statusbar.setObjectName("statusbar")
        MainWindow.setStatusBar(self.statusbar)
        self.actionLogin = QtWidgets.QAction(MainWindow)
        self.actionLogin.setObjectName("actionLogin")
        self.menuAction.addAction(self.actionLogin)
        self.menubar.addAction(self.menuAction.menuAction())

        self.retranslateUi(MainWindow)
        QtCore.QMetaObject.connectSlotsByName(MainWindow)

    def retranslateUi(self, MainWindow):
        _translate = QtCore.QCoreApplication.translate
        MainWindow.setWindowTitle(_translate("MainWindow", "Excel Uploader"))
        self.label_header.setText(_translate("MainWindow", "Excel Uploader"))
        self.pushButton_ok.setText(_translate("MainWindow", "Ok"))
        self.pushButton_close.setText(_translate("MainWindow", "Close"))
        self.radioButton_csv.setText(_translate("MainWindow", "Generate CSV"))
        self.radioButton_excl.setText(_translate("MainWindow", "Upload Excel"))
        self.pushButton_browse.setText(_translate("MainWindow", "Browse"))
        self.menuAction.setTitle(_translate("MainWindow", "Action"))
        self.actionLogin.setText(_translate("MainWindow", "Login"))


if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    MainWindow = QtWidgets.QMainWindow()
    ui = Ui_MainWindow()
    ui.setupUi(MainWindow)
    MainWindow.show()
    sys.exit(app.exec_())
