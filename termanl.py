from subprocess import run

while True:
    com = input("Enter command$ ")
    if com.lower() == 'exit':
        exit()
    try:
    
        run(com)
    except:
        print("the command is not found?")