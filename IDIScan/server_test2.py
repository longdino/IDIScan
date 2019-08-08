#!/usr/bin/env python3
import asyncio
import pymysql
import datetime

mydb = pymysql.connect(host = "localhost", user = "hayoung", password = "1020", db = "samples")
mycursor = mydb.cursor()

async def handle_echo(reader, writer):
    data = await reader.read(512)
    message = data.decode()
    if len(message) > 0:
        # to give options for location
        if message == "Location Request":
            print("Client: " + message)
            loc = sortList(mycursor)
            writer.write(loc)
            #print("sent")
            await writer.drain()
            writer.close()
        # when user clicked send
        else:
            print("Client: " + message)

            qrCode = ""

            # assign variables
            inputs = getInputs(message, qrCode)
            serial_id = inputs[0]
            location = inputs[1]
            day = getDateTime()
            sc_date = day[0]
            sc_time = day[1]

            # update database
            mydbOperation(mycursor, serial_id, location, sc_date, sc_time)
            mydb.commit()

            #getAll(mycursor)

            # send device info to user
            sdata = sendMessage(mycursor, serial_id)
            writer.write(sdata)
            #print("sent")
            await writer.drain()
            writer.close()

# Update or insert the  serial id and location of the device in the database
def mydbOperation(mycursor, serial_id, location, day, time):    
    mydb.commit()
    mycursor.execute("SELECT COUNT(SERIAL_ID) FROM DEVICE WHERE SERIAL_ID = %s", (serial_id,))
    myresult = mycursor.fetchall()
    count = myresult[0][0]
    print(count)
        # If the scanned code is already in database, update location
    if count > 0:
        print("Already Exists")
        # line 62-68 won't be executed since the app will display warning message if location is not given.
        if location == None: 
            location = getLocation(mycursor, serial_id)
            if location == None:
                location = input("Update the location: ")
            else:
                print("Location of the device " + serial_id + ": " + location)
                #break
        sql = "UPDATE DEVICE SET LOCATION = %s, SC_DATE = %s, SC_TIME = %s WHERE SERIAL_ID = %s"
        val = (location, day, time, serial_id)
        mycursor.execute(sql, val)
        print("Updating the location")
        #break
    # If the scanned code is not in database
    elif count == 0:
        print("needs to update")
        sql = "INSERT INTO DEVICE(SERIAL_ID, LOCATION, SC_DATE, SC_TIME) VALUES(%s, %s, %s, %s)"
        val = (serial_id, location, day, time)
        mycursor.execute(sql, val)
        #break
    return

# Output the updated database << debugging method
def getAll(mycursor):
    mycursor.execute("SELECT * FROM DEVICE")
    mylist = mycursor.fetchall()
    
    for x in mylist:
        print(x)
    
    return

# Get the inputs
def getInputs(message, qrCode):
    if message[0:5] == "http:":
        qrCode = message
    # later get the serial_id based on the qrcode
    else:
        inputs = message.split('|')
        for x in inputs:
            if x == None:
                raise Exception("Couldn't receive all data.")
                return
    return inputs

# Get the location
def getLocation(mycursor, serial_id):
    mycursor.execute("SELECT LOCATION FROM DEVICE WHERE DEVICE.SERIAL_ID = %s", (serial_id,))
    mylocation = mycursor.fetchall()
    return mylocation[0][0]

# Get the date
def getDateTime():
    now = datetime.datetime.now()
    day = now.strftime("%Y-%m-%d")
    time = now.strftime("%H:%M:%S")
    
    return day, time

# Write the send message to the client
def sendMessage(mycursor, serial_id):
    mycursor.execute("SELECT * FROM DEVICE WHERE DEVICE.SERIAL_ID = %s", (serial_id,))
    #print(serial_id)
    myinfo = mycursor.fetchall()
    #print(myinfo)
    respond = "ID: {} \nSerial ID: {} \nMac Address: \n\t{} \nLocation: {} \nName: {} \nModel: {} \nDate: {} \nTime: {} \nNote: {} \n".format(myinfo[0][0], myinfo[0][1], myinfo[0][2], myinfo[0][3], myinfo[0][4], myinfo[0][5], myinfo[0][6], myinfo[0][7], myinfo[0][8])
    #print(respond)
    message = str.encode(respond)
    return message

# Get the list of the location of the data sorted from the database
def sortList(mycursor):
    mycursor.execute("SELECT DISTINCT LOCATION FROM DEVICE")
    mylocation = mycursor.fetchall()
    list_loc = []
    for loc in mylocation:
        mycursor.execute("SELECT SC_DATE, SC_TIME FROM DEVICE WHERE LOCATION = %s ORDER BY SC_DATE DESC, SC_TIME DESC LIMIT 1", (loc,))
        loc_date = mycursor.fetchall()
        list_loc.append((loc_date[0][0], loc_date[0][1], loc[0]))
    
    list_loc = sorted(list_loc, reverse = True)
    #print(list_loc)

    option = []
    for loc in list_loc:
        option.append(loc[2])

    # Convert it into one buffer or string to send
    onestring = "|".join(option)#list_loc)
    onestring += " \n"
    s_opt = str.encode(onestring)
    print(s_opt)
    
    return s_opt

def main():
    serial_id = ""
    qrCode = ""
    location = None
    
    loop = asyncio.get_event_loop()
    coro = asyncio.start_server(handle_echo, '192.168.20.10', 9611, loop=loop)
    server = loop.run_until_complete(coro)

    # Serve requests until Ctrl+C is pressed
    print("Serving on {}".format(server.sockets[0].getsockname()))
    try:
        loop.run_forever()
    
    except KeyboardInterrupt:
        pass

    # Close the server
    server.close()
    loop.run_until_complete(server.wait_closed())
    loop.close()

if __name__ == "__main__":
    main()

