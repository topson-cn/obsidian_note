```
context : repayengine and repayengine.RepayApplyController.repayApplyResult and httpin |
select
json_extract(msg, '$.requestUri') as requestUri,
json_extract(msg, '$.commonRequestParameters.r_e[0]') as r_e,
count(1) total_req,
sum(if(cast(json_extract("msg.responseBody", '$.createAt') as bigint) >= 1766714648000, 1, 0)) month_in_req_3,
sum(if(cast(json_extract("msg.responseBody", '$.createAt') as bigint) >= 1756173848000 and cast(json_extract("msg.responseBody", '$.createAt') as bigint) < 1766714648000, 1, 0)) month_in_req_6,
sum(if(cast(json_extract("msg.responseBody", '$.createAt') as bigint) < 1756173848000, 1, 0)) month_out_req_6
from log
group by requestUri,r_e
```

```
context : repayengine and repayengine.DataManageController.queryRepayApply and httpin |

select

json_extract(msg, '$.requestUri') as requestUri,

json_extract(msg, '$.commonRequestParameters.r_e[0]') as r_e,

count(1) total_req,

-- 先转字符串再判断非空，避免JSON类型判断问题

sum(if(CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) is not null, 1, 0)) as req_with_time,

sum(if(CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) is null, 1, 0)) as req_with_out_time,

-- 3个月内：JSON转字符串 + 非空 + 字符串≥目标值

sum(if(

CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) is not null

and CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) >= '1766714648000',

1, 0

)) as month_in_req_3,

-- 3-6个月：JSON转字符串 + 非空 + 字符串≥6个月值 且 <3个月值

sum(if(

CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) is not null

and CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) >= '1756173848000'

and CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) < '1766714648000',

1, 0

)) as month_in_req_6,

-- 6个月外：JSON转字符串 + 非空 + 字符串<6个月值

sum(if(

CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) is not null

and CAST(json_extract("msg.requestBody", '$.timeStart') AS VARCHAR) < '1756173848000',

1, 0

)) as month_out_req_6

from log

group by requestUri,r_e
```

```
context : repayengine and repayengine.DataManageController.queryDeductBill and httpin |
select
  json_extract(msg, '$.requestUri') as requestUri,
  json_extract(msg, '$.commonRequestParameters.r_e[0]') as r_e,
  count(1) total_req,
  -- 保留你指定的 json_extract 格式，仅增加容错判断
  sum(if(
    json_extract("msg.requestBody", '$.timeStart') is not null ,
    1, 0
  )) as req_with_time,
  sum(if(
    json_extract("msg.requestBody", '$.timeStart') is null,
    1, 0
  )) as req_with_out_time
from log
group by requestUri,r_e
```

```
context : repayengine and repayengine.DataManageController.queryRefundBill and httpin |
select
  json_extract(msg, '$.requestUri') as requestUri,
  json_extract(msg, '$.commonRequestParameters.r_e[0]') as r_e,
  count(1) total_req,
  -- 保留你指定的 json_extract 格式，仅增加容错判断
  sum(if(
    json_extract("msg.requestBody", '$.timeStart') is not null ,
    1, 0
  )) as req_with_time,
  sum(if(
    json_extract("msg.requestBody", '$.timeStart') is null,
    1, 0
  )) as req_with_out_time
from log
group by requestUri,r_e
```