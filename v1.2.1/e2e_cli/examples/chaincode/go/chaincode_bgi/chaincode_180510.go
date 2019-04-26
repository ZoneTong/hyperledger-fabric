/*
Copyright IBM Corp. 2016 All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

		 http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

//WARNING - this chaincode's ID is hard-coded in chaincode_example04 to illustrate one way of
//calling chaincode from a chaincode. If this example is modified, chaincode_example04.go has
//to be modified as well with the new ID of chaincode_example02.
//chaincode_example05 show's how chaincode ID can be passed in as a parameter instead of
//hard-coding.

import (
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	pb "github.com/hyperledger/fabric/protos/peer"
)

// SimpleChaincode example simple Chaincode implementation
type SimpleChaincode struct {
}

func (t *SimpleChaincode) Init(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("ex02 Init")
	_, args := stub.GetFunctionAndParameters()
	var A, B string    // Entities
	var Aval, Bval int // Asset holdings
	var err error

	if len(args) != 4 {
		return shim.Error("Incorrect number of arguments. Expecting 4")
	}

	// Initialize the chaincode
	A = args[0]
	Aval, err = strconv.Atoi(args[1])
	if err != nil {
		return shim.Error("Expecting integer value for asset holding")
	}
	B = args[2]
	Bval, err = strconv.Atoi(args[3])
	if err != nil {
		return shim.Error("Expecting integer value for asset holding")
	}
	fmt.Printf("Aval = %d, Bval = %d\n", Aval, Bval)

	// Write the state to the ledger
	err = stub.PutState(A, []byte(strconv.Itoa(Aval)))
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(B, []byte(strconv.Itoa(Bval)))
	if err != nil {
		return shim.Error(err.Error())
	}

	// 初始化系统钱包6亿token
	// system_wallet := "02dd5b60206ba8752611c1f564828ddb5111bce5c3ed34cb3e2048aff76fcdfccc"
	// exist, err := checkWalletExisted(stub, system_wallet)
	// if !exist {
	// 	err = stub.PutState(system_wallet, []byte(fmt.Sprint(6e8)))
	// 	if err != nil {
	// 		return shim.Error(err.Error())
	// 	}
	// }

	return shim.Success(nil)
}

func (t *SimpleChaincode) Invoke(stub shim.ChaincodeStubInterface) pb.Response {
	fmt.Println("ex02 Invoke zht")
	function, args := stub.GetFunctionAndParameters()
	if function == "invoke" {
		// Make payment of X units from A to B
		return t.invoke(stub, args)
	} else if function == "delete" {
		// Deletes an entity from its state
		return t.delete(stub, args)
	} else if function == "query" {
		// the old "Query" is now implemtned in invoke
		return t.query(stub, args)
	} else if function == "add" {
		return t.add(stub, args)

		// 钱包
	} else if function == "walletCreate" {
		return t.walletCreate(stub, args)
		// } else if function == "walletAward" {
		// return t.walletAward(stub, args)
	} else if function == "walletPay" {
		return t.walletPay(stub, args)
	}

	return shim.Error("Invalid invoke function name. Expecting 'invoke' 'delete' 'query' 'walletCreate' 'walletPay'") // 'walletAward'
}

// Transaction makes payment of X units from A to B
func (t *SimpleChaincode) invoke(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var A, B string    // Entities
	var Aval, Bval int // Asset holdings
	var X int          // Transaction value
	var err error

	if len(args) != 3 {
		return shim.Error("Incorrect number of arguments. Expecting 3")
	}

	A = args[0]
	B = args[1]

	// Get the state from the ledger
	// TODO: will be nice to have a GetAllState call to ledger
	Avalbytes, err := stub.GetState(A)
	if err != nil {
		return shim.Error("Failed to get state")
	}
	if Avalbytes == nil {
		return shim.Error("Entity not found")
	}
	Aval, _ = strconv.Atoi(string(Avalbytes))

	Bvalbytes, err := stub.GetState(B)
	if err != nil {
		return shim.Error("Failed to get state")
	}
	if Bvalbytes == nil {
		return shim.Error("Entity not found")
	}
	Bval, _ = strconv.Atoi(string(Bvalbytes))

	// Perform the execution
	X, err = strconv.Atoi(args[2])
	if err != nil {
		return shim.Error("Invalid transaction amount, expecting a integer value")
	}
	Aval = Aval - X
	Bval = Bval + X
	fmt.Printf("Aval = %d, Bval = %d\n", Aval, Bval)

	// Write the state back to the ledger
	err = stub.PutState(A, []byte(strconv.Itoa(Aval)))
	if err != nil {
		return shim.Error(err.Error())
	}

	err = stub.PutState(B, []byte(strconv.Itoa(Bval)))
	if err != nil {
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}

// Deletes an entity from state
func (t *SimpleChaincode) delete(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting 1")
	}

	A := args[0]

	// Delete the key from the state in ledger
	err := stub.DelState(A)
	if err != nil {
		return shim.Error("Failed to delete state")
	}

	return shim.Success(nil)
}

// query callback representing the query of a chaincode
func (t *SimpleChaincode) query(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var A string // Entities
	var err error

	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting name of the person to query")
	}

	A = args[0]

	// Get the state from the ledger
	Avalbytes, err := stub.GetState(A)

	if err != nil {
		jsonResp := "{\"Error\":\"Failed to get state for " + A + "\"}"
		return shim.Error(jsonResp)
	}

	if Avalbytes == nil {
		jsonResp := "{\"Error\":\"Nil amount for " + A + "\"}"
		return shim.Error(jsonResp)
	}

	jsonResp := "{\"Name\":\"" + A + "\",\"Amount\":\"" + string(Avalbytes) + "\"}"
	fmt.Printf("Query Response:%s\n", jsonResp)
	return shim.Success(Avalbytes)
}

//added by pgm ,2018 04 02
// Transaction makes payment of X units from A to B
func (t *SimpleChaincode) add(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	var A, Aval string // Entities
	var err error

	if len(args) != 2 {
		return shim.Error("Incorrect number of arguments. Expecting 2")
	}

	A = args[0]
	Aval = args[1]

	// Write the state back to the ledger
	err = stub.PutState(A, []byte((Aval)))
	if err != nil {
		return shim.Error(err.Error())
	}
	return shim.Success(nil)
}

/** Descrption: 钱包用户创建
 *  CreateTime: 2018/12/11 17:24:53
 *      Author: zhoutong@genomics.cn
 */
func (t *SimpleChaincode) walletCreate(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	if len(args) != 1 {
		return shim.Error("Incorrect number of arguments. Expecting 1")
	}

	A := args[0]

	exist, err := checkWalletExisted(stub, A)
	if err != nil {
		return shim.Error(err.Error())
	}

	if exist {
		return shim.Error(fmt.Sprintf("Wallet %v has existed", A))
	}

	err = stub.PutState(A, []byte(fmt.Sprint(0.0)))
	if err != nil {
		return shim.Error(err.Error())
	}
	return shim.Success(nil)
}

/** Descrption: 钱包充钱，天赐之
 *  CreateTime: 2018/12/11 17:24:53
 *      Author: zhoutong@genomics.cn
 */
// func (t *SimpleChaincode) walletAward(stub shim.ChaincodeStubInterface, args []string) pb.Response {
// 	if len(args) != 2 {
// 		return shim.Error("Incorrect number of arguments. Expecting 2")
// 	}

// 	A := args[0]

// 	Aval, err := getWalletBalance(stub, A)
// 	if err != nil {
// 		return shim.Error(fmt.Sprintf("{\"Error\":\"parse wallet %v amount error: %v\"}", A, err))
// 	}

// 	X, err := strconv.ParseFloat(args[1], 64)
// 	if err != nil {
// 		return shim.Error("Invalid wallet amount, expecting a float value")
// 	}

// 	Aval += X
// 	err = stub.PutState(A, []byte(fmt.Sprint(Aval)))
// 	if err != nil {
// 		return shim.Error(err.Error())
// 	}
// 	return shim.Success(nil)
// }

/** Descrption: 获取钱包余额
 *  CreateTime: 2018/12/12 11:29:06
 *      Author: zhoutong@genomics.cn
 */
func getWalletBalance(stub shim.ChaincodeStubInterface, addr string) (Aval float64, err error) {
	Avalbytes, err := stub.GetState(addr)
	if err != nil {
		err = fmt.Errorf("Failed to get state for %v: %v", addr, err)
		return
	}

	if Avalbytes == nil {
		err = fmt.Errorf("Nil amount for %v", addr)
		return
	}

	Aval, err = strconv.ParseFloat(string(Avalbytes), 64)
	if err != nil {
		err = fmt.Errorf("Parse wallet %v amount error: %v", addr, err)
		return
	}
	return
}

/** Descrption: 确认钱包存在
 *  CreateTime: 2018/12/12 11:28:30
 *      Author: zhoutong@genomics.cn
 */
func checkWalletExisted(stub shim.ChaincodeStubInterface, addr string) (exist bool, err error) {
	Avalbytes, err := stub.GetState(addr)
	if err != nil {
		err = fmt.Errorf("Failed to get state for %v: %v", addr, err)
		return
	}

	if Avalbytes != nil {
		exist = true
		return
	}
	return
}

/** Descrption: 钱包付款，转同样的金额给多人
 *  CreateTime: 2018/12/11 17:26:06
 *      Author: zhoutong@genomics.cn
 */
func (t *SimpleChaincode) walletPay(stub shim.ChaincodeStubInterface, args []string) pb.Response {
	// senderAddr,amount,recieverAddrs
	if len(args) < 3 {
		return shim.Error("Incorrect number of arguments. Expecting at least 3")
	}

	A := args[0]
	Aval, err := getWalletBalance(stub, A)
	if err != nil {
		return shim.Error(err.Error())
	}

	X, err := strconv.ParseFloat(args[1], 64)
	if err != nil {
		return shim.Error("Invalid wallet amount, expecting a float value")
	}

	// 防止转账变收账
	if X <= 0 {
		return shim.Error("Invalid wallet amount, expecting a positive value")
	}

	recievers := args[2:]
	cost := X * float64(len(recievers))

	// 余额不足
	if Aval < cost {
		return shim.Error("Balance is not enough")
	}

	Aval -= cost
	err = stub.PutState(A, []byte(fmt.Sprint(Aval)))
	if err != nil {
		return shim.Error(err.Error())
	}

	// 此时新Aval还没写入数据库，GetState(A)仍然是原值。需等待合约成功才会正式写入值

	var recvCounts = make(map[string]int) // 收账人出现次数
	for _, B := range recievers {
		// 不允许转账给自己
		if B == A {
			return shim.Error("Paying to yourself is not allowed")
		}

		recvCounts[B]++
	}

	for B, cnt := range recvCounts {
		Bval, err := getWalletBalance(stub, B)
		if err != nil {
			return shim.Error(err.Error())
		}

		// B出现多次时，表示付给B多倍金额
		Bval += X * float64(cnt)
		err = stub.PutState(B, []byte(fmt.Sprint(Bval)))
		if err != nil {
			shim.Error(err.Error())
		}
	}

	return shim.Success(nil)
}

func main() {
	err := shim.Start(new(SimpleChaincode))
	if err != nil {
		fmt.Printf("Error starting Simple chaincode: %s", err)
	}
}
