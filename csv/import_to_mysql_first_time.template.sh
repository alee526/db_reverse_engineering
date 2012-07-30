#!/bin/sh

default_user="root"
dbpasswd=""
your_dbname=""
datadir=""
extra_sql=""
extra_data=""

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
      #elif [[ $i =~ "date" ]] ; then
      #  result="$result\`${i}\` DATETIME DEFAULT NULL,";
      #elif [[ $i =~ "flag" ]] ; then
      #  result="$result\`${i}\` INT(11) NOT NULL,";
      else
        if [ $i = $pppp ] ; then
          # IF the first column is a text, primary key length reset to 767 (max)
          result="$result\`${i}\` VARCHAR(767) DEFAULT NULL,";
        else
          result="$result\`${i}\` VARCHAR(1024) DEFAULT NULL,";
        fi
      fi
    done
    result="$result PRIMARY KEY ($pppp)"
    
    echo "$result"
}

function usage()
{
cat << EOF
  usage: $0 options

  This script import CSV files and create default table from CSV filename
  by picking the prefix before the _ (underscore) in the filename. Additional
  SQL can be trigger to update indexes, FK, etc afterward, and additional 
  table can be reloaded once the SQL are triggered if the column datatype
  were altered.

  OPTIONS:
   -h      Show this message
   -d      database name
   -p      root account password to access database specified by -d
   -i      input folder to load all CSV files
   -s      additional SQL files to run. If the file has a number prefix, 
           numerical order is followed.
   -t      additional table files to reload after option -s. The CSV file will
           be reloaded by associating the table_name with the CSV files under
           option -i

  Example
  $0 -p dbpasswd -d dbname -i csv_dir
  $0 -p dbpasswd -d dbname -i csv_dir -s sql_dir
  $0 -p dbpasswd -d mysql_db_name -i /home/foo/csvdir/ -s /home/foo/additional_sql/ -t "table1 table2"
EOF
}

while getopts “hd:p:i:s:t:” OPTION
do
   case $OPTION in
     h)
       usage
       exit 1
       ;;
     i)
       datadir=$OPTARG
       ;;
     p)
       dbpasswd=$OPTARG
       ;;
     d)
       your_dbname=$OPTARG
       ;;
     s)
       extra_sql=$OPTARG
       ;;
     t)
       extra_data=$OPTARG
       ;;
     ?)
       usage
       exit
       ;;
   esac
done

if [ "x${dbpasswd}" = "x" -o "x${your_dbname}" = "x" -o "x${datadir}" = "x" ] ; then
  echo "fail - missing required parameters, please make sure you have escapded punctioations and spaces with \"\"" 1>&2
  usage
  exit
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
echo "USE ${your_dbname}; LOAD DATA LOCAL INFILE '$csvname' INTO TABLE ${your_dbname}.$tbname FIELDS TERMINATED BY ',' ENCLOSED BY '\"' ESCAPED BY '\"' LINES TERMINATED BY '\n';" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}
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

if [ "x${extra_data}" != "x" ] ; then
  for tablename in $extra_data
  do
    fname=`find $datadir -type f -name "$tablename*.csv"`
    if [ ! -e "$fname" ] ; then
      echo "warn - couldnt find $fname, skipping"
      continue
    else
      echo "ok - re-importing data from $tablename"
      echo "USE ${your_dbname}; LOAD DATA LOCAL INFILE '$fname' INTO TABLE ${your_dbname}.$tablename FIELDS TERMINATED BY ',' ENCLOSED BY '\"' ESCAPED BY '\"' LINES TERMINATED BY '\n';" | /usr/local/mysql/bin/mysql -u ${default_user} --password=${dbpasswd}
    fi
  done
fi



