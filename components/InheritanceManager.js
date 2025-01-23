import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import InheritanceManagerABI from '../../artifacts/contracts/InheritanceManager.sol/InheritanceManager.json';

const InheritanceManager = () => {
    const [account, setAccount] = useState(null);
    const [contract, setContract] = useState(null);
    const [beneficiaryAddress, setBeneficiaryAddress] = useState('');
    const [beneficiaryShare, setBeneficiaryShare] = useState('');
    const [validatorAddress, setValidatorAddress] = useState('');
    
    useEffect(() => {
        connectWallet();
    }, []);
    
    const connectWallet = async () => {
        if (typeof window.ethereum !== 'undefined') {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
                setAccount(accounts[0]);
                
                const provider = new ethers.providers.Web3Provider(window.ethereum);
                const signer = provider.getSigner();
                
                const contractAddress = "YOUR_CONTRACT_ADDRESS";
                const contractInstance = new ethers.Contract(
                    contractAddress,
                    InheritanceManagerABI.abi,
                    signer
                );
                
                setContract(contractInstance);
            } catch (error) {
                console.error("Bağlantı hatası:", error);
            }
        }
    };
    
    const createInheritance = async () => {
        try {
            const tx = await contract.createInheritance(2);
            await tx.wait();
            alert("Miras planı oluşturuldu!");
        } catch (error) {
            console.error("İşlem hatası:", error);
        }
    };
    
    const addBeneficiary = async () => {
        try {
            const tx = await contract.addBeneficiary(beneficiaryAddress, beneficiaryShare);
            await tx.wait();
            alert("Varis eklendi!");
        } catch (error) {
            console.error("İşlem hatası:", error);
        }
    };
    
    const addValidator = async () => {
        try {
            const tx = await contract.addValidator(validatorAddress);
            await tx.wait();
            alert("Doğrulayıcı eklendi!");
        } catch (error) {
            console.error("İşlem hatası:", error);
        }
    };
    
    return (
        <div>
            <h1>Miras Yönetim Sistemi</h1>
            {!account ? (
                <button onClick={connectWallet}>Cüzdana Bağlan</button>
            ) : (
                <div>
                    <p>Bağlı Hesap: {account}</p>
                    <button onClick={createInheritance}>Miras Planı Oluştur</button>
                    
                    <div>
                        <h3>Varis Ekle</h3>
                        <input
                            type="text"
                            placeholder="Varis Adresi"
                            value={beneficiaryAddress}
                            onChange={(e) => setBeneficiaryAddress(e.target.value)}
                        />
                        <input
                            type="number"
                            placeholder="Pay (100 = %1)"
                            value={beneficiaryShare}
                            onChange={(e) => setBeneficiaryShare(e.target.value)}
                        />
                        <button onClick={addBeneficiary}>Varis Ekle</button>
                    </div>
                    
                    <div>
                        <h3>Doğrulayıcı Ekle</h3>
                        <input
                            type="text"
                            placeholder="Doğrulayıcı Adresi"
                            value={validatorAddress}
                            onChange={(e) => setValidatorAddress(e.target.value)}
                        />
                        <button onClick={addValidator}>Doğrulayıcı Ekle</button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default InheritanceManager; 