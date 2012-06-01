#!/bin/sh

default_user="root"
dbpasswd="$1"
your_dbname="$2"
datadir="$3"
extra_sql="$4"

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

function help_exit()
{
  echo "Usage:"
  echo "$0 db_password db_name CSV_dir_path optional_extra_sql"
  echo "Example:"
  echo "$0 abc123 mydb ./da/source/csv/"
  echo "$0 abc123 mydb ./da/source/csv/ ./sql/update_table_fields_types/"
  exit -1
}

if [ "x${dbpasswd}" = "x" -o "x${your_dbname}" = "x" -o "x${datadir}" = "x" ] ; then
  echo "fail - missing required parameters, please make sure you have escapded punctioations and spaces with \"\"" 1>&2
  help_exit
fi

echo "ok - applying default username ${default_user}"

echo "DROP SCHEMA IF EXISTS ${your_dbname}; CREATE SCHEMA IF NOT EXISTS ${your_dbname}" 
echo "DROP SCHEMA IF EXISTS ${your_dbname}; CREATE SCHEMA IF NOT EXISTS ${your_dbname};" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}

for csvname in `find $datadir -type f -name "*.csv"`
do
  tbname=`basename $csvname | sed -e "s/\.csv$//g" | cut -d "-" -f1`
  echo "ok - importing $tbname with $csvname"
col_field=`head -n 1 $csvname`
column=`gen_column $col_field`

echo "USE ${your_dbname}; DROP TABLE IF EXISTS ${your_dbname}.$tbname" 
echo "USE ${your_dbname}; DROP TABLE IF EXISTS ${your_dbname}.$tbname" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}
if [ $? -ne 0 ] ; then
  exit
fi
echo "USE ${your_dbname}; CREATE TABLE ${your_dbname}.$tbname ($column)" 
echo "USE ${your_dbname}; CREATE TABLE ${your_dbname}.$tbname ($column) ENGINE=INNODB" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}
if [ $? -ne 0 ] ; then
  exit
fi
echo "USE ${your_dbname}; LOAD DATA LOCAL INFILE '$csvname' INTO TABLE ${your_dbname}.$tbname FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n';" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}
if [ $? -ne 0 ] ; then
  exit
fi
done


if [ -d "$extra_sql" ] ; then
  for sqlf in `find -s "$extra_sql" -type f -name "*.sql"`
  do
    echo "ok - importing extra SQL $sqlf"
    /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd} -D ${your_dbname} < $sqlf
  done  
fi

