#!/usr/bin/python
import optparse
import telnetlib
import os
import time

def getargs():
    usage='usage: %prog [options]'
    parser=optparse.OptionParser(usage,add_help_option=False)
    
    parser.add_option('-h','--host',action='store',type='string',dest='ip',default='xxx.xxx.xxx.xxx',)
    parser.add_option('-p','--port',action='store',type='int',dest='port',default=1,)
    parser.add_option('-s','--speed-duplex',action='store',dest='action',choices=['10h','10f','100h','auto','down','up'])
   
    opt,args=parser.parse_args()
    print 'IP: ',opt.ip
    print 'Port: ',opt.port  
    
    return opt

def main(h,p,s):
    try:
          tn=telnetlib.Telnet(h,23)
    except:
           print('Unable connect to the host')
    else:
         tn.write("admin\r")
         tn.write("bonOdrib\r")
         #tn.write("solekam1\r")
    
    result={}

    if s=='10h':
         tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"speed-duplex 10half\n"+"exit\n"+"exit\n")
    elif s=='10f':
           tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"speed-duplex 10full\n"+"exit\n"+"exit\n")
    elif s=='100h':
           tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"speed-duplex 100half\n"+"exit\n"+"exit\n") 
    elif s=='auto':
           tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"speed-duplex 100full\n"+"exit\n"+"exit\n")      
    elif s=='down':
           tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"shutdown\n"+"exit\n"+"exit\n")
    elif s=='up':
           tn.write("conf\n"+"int eth 1/"+str(p)+"\n"+"no shutdown\n"+"exit\n"+"exit\n")

    tn.write("show int switchport eth 1/"+str(p)+"\n")
    tn.write("show mac-address-table int eth 1/"+str(p)+"\n")
    tn.write("show cable-diagnostics int eth 1/"+str(p)+"\n")
    tn.write("show int status eth 1/"+str(p)+"\n"+"a"+"\n")
    tn.write("show int counters eth 1/"+str(p)+"\n"+"a"+"\n") 
    
    tn.write('exit\n')
    st=tn.read_all()
    time.sleep(3)
    
    file_log=open('edge.txt','w')
    file_log.write(st)
    file_log2=open('edge.txt')
    macs=[ ]
    for line in file_log2:
        if 'Native VLAN' in line:
            string=line.split()
            vlan=string[string.index('VLAN')+2]
            result['vlan']=vlan
            break
        
    for line in file_log2:
        string=line.split()
        if 'Learn' in string:
            mac=string[string.index('Learn')-2]
            macs.append(mac)
            result['mac']=macs
        elif 'FE' in string:
            pair1=string[string.index('FE')+2]
            pair2=string[string.index('FE')+4]
            status=string[string.index('FE')+1]
            result['pair1']=pair1
            result['pair2']=pair1
            result['Link status']=status
        elif 'Admin' in string:
            try: 
                 ports_status=string[string.index('Admin')+2]
                 result['port']=ports_status
            except:
                    result['port']='Down'  
        elif "Operation Speed-duplex" in line:
            speed=string[string.index('Speed-duplex')+2]
            result['speed']=speed
        elif 'Up Time' in line:
            uptime=line[27:43]
            result['uptime']=uptime
        elif 'Error Input' in line:
            string=line.split()
            error_input=string[string.index('Error')-1]
            result['in_error']='Input Error '+error_input
        elif 'Error Output' in line:
            string=line.split()
            error_output=string[string.index('Error')-1]
            result['ou_error']='Output Error '+error_output
        elif 'CRC Align Errors' in line:
            string=line.split()
            error_crc=string[string.index('CRC')-1]
            result['crc']='CRC Error '+error_crc
        elif 'Drop Events' in line:
            drop=string[string.index('Drop')-1]
            result['drop']='Drop error '+drop
                       
    return result
       
if __name__=='__main__':
     arg=getargs()
     res=main(h=arg.ip,p=arg.port,s=arg.action)
     os.remove('edge.txt')
     if res['pair1']=='No':
          cable=' cable'
     elif res['pair1']=='Not':
          cable=' tested'
     elif res['pair1']=='OK':
          cable=''
          
     if 'mac'not  in res.keys():
            mac='None'

     if 'uptime' not in res.keys():
          res['uptime']='None'
    
     print ('Port Status  '+' '*3+'-'+' '*1+res['port'])
     print ('Vlanid          - '+res['vlan'])
     print ('Port Connection - '+res['speed'])
     print ('Link Status     - '+'Link '+ res['Link status'])
     print ('Cable Length    - '+'pairA: '+ res['pair1']+cable+'\n'+18*' '+'pairB: '+res['pair2']+cable)
     print ('Link Uptime     - '+res['uptime'])
     print ('Errors ' +9*' '+'- '  +res['in_error']) 
     print (' '*18+res['ou_error'])
     
     if 'mac' not in res.keys():
           print 'Mac Addresses   - '+mac
     else:
           print 'Mac Addresses   -'
           for val in res['mac']:print(' '*18+ val)
           
     
     