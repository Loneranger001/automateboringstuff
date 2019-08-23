
# Object to hold the row in excel.


class recordObj:
    def __init__(self, sheet_name, column_name, col_value, group_id):
        self.sheet_name = sheet_name
        self.column_name = column_name
        self.col_value = col_value
        self.group_id = group_id

