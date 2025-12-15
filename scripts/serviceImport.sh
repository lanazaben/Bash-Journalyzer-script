if [ $# -ne 3 ]; then
  echo "Usage: serviceImport \"file name\"" since-- " "time range""
  exit 1
fi

# Extract field 5 from journal file and save to service1.txt
echo "journalctl --file "$1" | cut -d " " -f5 | cut -d "[" -f1 > service1.txt"
serv=$(journalctl --file "$1" | cut -d " " -f5 | cut -d "[" -f1 > service1.txt)
echo "$serv"
#Create temp.txt
> temp.txt # clears or creates it
# Remove duplicates manually
 while read -r line; do
	 duplicate=false
	 while read -r ser; do
		 if [ "$line" = "$ser" ]; then
			 duplicate=true
			 break
			 fi
		 done < temp.txt 
		 if [ "$duplicate" = false ]; then
			 echo "$line" >> temp.txt
		 fi
 done < service1.txt
