#!/bin/sh

dbpasswd="$1"
your_dbname="$2"
datadir="$3"

function gen_column()
{
    header=$1
    header_tmp=`echo $header | tr -d '\n' | tr -d '\r'`
    result=""
    pppp=""
    IFS=',' 
    for i in $header_tmp
    do
      if [ "x${pppp}" = "x" ] ; then
        pppp=$i
      fi
      if [[ $i =~ "_id" ]] ; then
        result="$result\`${i}\` INT(11) NOT NULL,";
      elif [[ $i =~ "date" ]] ; then
        result="$result\`${i}\` DATETIME DEFAULT NULL,";
      #elif [[ $i =~ "flag" ]] ; then
      #  result="$result\`${i}\` INT(11) NOT NULL,";
      else
        result="$result\`${i}\` VARCHAR(128) DEFAULT NULL,";
      fi
    done
    result="$result PRIMARY KEY ($pppp)"
    
    echo "$result"
}

echo "DROP SCHEMA IF EXISTS ${your_dbname}; CREATE SCHEMA IF NOT EXISTS ${your_dbname}" 
echo "DROP SCHEMA IF EXISTS ${your_dbname}; CREATE SCHEMA IF NOT EXISTS ${your_dbname};" | /usr/local/mysql/bin/mysql -u root --password=root

for csvname in `find $datadir -type f -name "*.csv"`
do
  tbname=`basename $csvname | sed -e "s/\.csv$//g" | cut -d "-" -f1`
  echo "ok - importing $tbname with $csvname"
col_field=`head -n 1 $csvname`
column=`gen_column $col_field`



echo "USE ${your_dbname}; DROP TABLE IF EXISTS ${your_dbname}.$tbname" 
echo "USE ${your_dbname}; DROP TABLE IF EXISTS ${your_dbname}.$tbname" | /usr/local/mysql/bin/mysql -u root --password=root
if [ $? -ne 0 ] ; then
  exit
fi
echo "USE ${your_dbname}; CREATE TABLE ${your_dbname}.$tbname ($column)" 
echo "USE ${your_dbname}; CREATE TABLE ${your_dbname}.$tbname ($column) ENGINE=INNODB" | /usr/local/mysql/bin/mysql -u root --password=root
if [ $? -ne 0 ] ; then
  exit
fi
echo "USE ${your_dbname}; LOAD DATA LOCAL INFILE '$csvname' INTO TABLE ${your_dbname}.$tbname FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" | /usr/local/mysql/bin/mysql -u root --password=root
if [ $? -ne 0 ] ; then
  exit
fi
done



